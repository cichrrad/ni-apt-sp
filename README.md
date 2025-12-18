# NI-RUB Semestal project -- Random fuzzer

## Requirements

If you run it using the included devcontainer, all should work out of the box. For running without the devcontainer:

* Ruby + bundle (`make build` will install gems in `Gemfile`)
* C/CPP compiler (`Makefile` uses `cc`) able to build mock binaries with ASAN flags.

### !ASAN CAVEAT!

I had **a lot** of issues with running binaries compiled with ASAN flags to allow for ASAN oracle to detect stack/heap buffer crashes. This might very well be some fumble on my side/machine + because I doing it all in devcontainer. To make it work, I had to allow the devcointer to disable (for the fuzzer campaign launch command) address randomization.  
```json
"runArgs": [
    "--cap-add=SYS_ADMIN",
    "--cap-add=SYS_PTRACE",
    "--security-opt", "seccomp=unconfined"
  ],:
```
```bash
#from setarch man pages
       -R, --addr-no-randomize
           Disables randomization of the virtual address space. Turns on
           ADDR_NO_RANDOMIZE.
```
This is the reason in the `Makefile`, launch commands are prepended with `setarch $(uname -m) -R`. You may try the lines without this, and if it works, good for you.

Without this option, it's 50/50 shot of the program (the compiled binary we are fuzzing) running or ASAN exploding and killing it, stoping the fuzzer in its tracks. To be honest, I have little idea or will to figure out what & why is going on exactly. It may very well run OK without the flag on your system.

## Project structure

Project root (`fuzzer`) has following subdirectories:

* `lib` -- `.rb` source files for all the fuzzer components (split into subdirectories by purpose/what I thought was fine).

* `spec` -- directory with `rspec` tests. Its structure copies `lib` directory, so its more than clear to see what spec maps to what component. I've tried to test each component separately to verify all interesting scenarios are handled gracefully and as I would want. Regarding end-to-end tests, I struggled with coming up with a way to test the binary file without actually running a campaign, so I at least ran it on mock binary which produces various bugs and sanity checked that they were caught and the stats look fine (see `example_fuzz_run`).

  > Potential TODO -- aruba gem e2e?

* `target_programs` -- has `src` and empty `binary` subdirectories. It containes mock `.c` programs that are used in `spec` testing (specifically in runner tests). As per Task 1, binaries for them are not present and will be compiled upon running tests, if they are missing.

## How it works

>**TL:DR** -- Fuzzer feeds generated inputs into runner -> runner runs target binary with the input -> runner captures output (return code, data streams etc.) -> outputs are handed to oracle chain for classification -> classified output is deduplicated & its input is minimized (if its the first time we see it) --> we update bug & fuzz campaign statistic

Fuzzer has multiple components (described below) and they all come together in `bin/fuzzer`. When campaign is started by entering something like:
```
export FUZZED_PROG=target_programs/binary/mock && export RESULT_FUZZ=./example_fuzz_run && export INPUT=stdin && export MINIMIZE=1 && export TIMEOUT=300 && make run
```
Fuzzer controller executable script `bin/fuzzer` is called. During initialization, it first validates it received all the required env vars (in and out paths) and captures the other ones (this is handled by `lib/config.rb`). 

After this (still during initialization), we create instances of all the objects (fuzzer components) we will use during the campaign -- these include mainly `@generator`,`@runner`,`@oracle`,`@deduplicator` etc. These correspond to fuzzer components and are described below.

A high-level picture of what the fuzzer campaign will do is visible in the `run` method (entry point for the whole campaign):

```ruby
  def run
    spawn_minimizer_workers
    setup_signal_traps
    spawn_timeout_thread

    begin
      run_main_fuzzing_loop
    ensure
      stop
    end
  end
```

The fuzzer will populate worker pool with forked processes that will run minimizing (`spawn_minimizer_workers`), setup signal traps to catch `CTRL+C` and shutdown signals, spawn timeout thread which will sleep for the time given by the `TIMEOUT` env var - 10 (buffer to ensure we save stats), then stop the campaign. In the meantime (until we kill the program or `TIMEOUT - 10` seconds pass), there are 1 fuzzing + 2 (by default) minimizer processes which do all the work. This is orchestrated in `run_main_fuzzing_loop`:

```ruby
  def run_main_fuzzing_loop
    @reporter.log_success('Fuzzer parent process running.')

    while @running
      begin
        # Manage Workers (Check for results, Assign work)
        process_worker_events
        distribute_work
        # Fuzz
        run_one_iteration
        @counter += 1
        @reporter.log_info("Fuzzed #{@counter} inputs.") if (@counter % 100).zero?
      rescue StandardError => e
        @reporter.log_error("Parent Loop Error: #{e.message}\n#{e.backtrace.join("\n")}")
        sleep 1
      end
    end
  end
``` 
This describes the **fuzzing process loop**. It is responsible for running the target binary with random generated inputs (`run_one_iteration`), as well as processing events that come from the minimizer processes -- either `:minimization_success` or `:new_bug_found` messages (in `process_worker_events`). Lastly, it manages the work distribution between the minimizers (`distribute_work`). This is done by maintaining `@pending_work` array of inputs that cause hang/crash and are in need of minimizing. Whether a worker is free or not is managed via flag `:busy`, which is set/unset upon sending work/recieving `:minimization_success` event. Minimizers run the target binary with provided input and preform delta-debugging minimization. Once program is killed / `TIMEOUT` is nearing, we save reports and wrap it up with `stop` (`shutdown_stats` inside).

Inside `run_one_iteration`, we generate new input, run the target binary with it, use oracle chain to classify it (hang/crash/success) and IF it was not a success, we add it to the array of work pending for minimization. 

```ruby
  def run_one_iteration
    input = @generator.next
    result = @runner.run(input)
    classification = @oracle.classify(result, input)

    @stats.record_run(result, classification)

    return if classification.pass?

    # Deduplicate
    return unless @deduplicator.add(classification.signature)

    @reporter.log_new_bug(classification)
    @stats.record_new_discovery

    # Queue for minimization
    @pending_work << [input, result, classification]
  end
```

## Example campaign

Can be found in `example_fuzz_run`. It was run with the command shown above (mock binary has to be compiled with `make build` first):

```
export FUZZED_PROG=target_programs/binary/mock && export RESULT_FUZZ=./example_fuzz_run && export INPUT=stdin && export MINIMIZE=1 && export TIMEOUT=300 && make run
```

## Fuzzer components

### `lib/generators/cstring_generator.rb`

Generates C string inputs for the runner. It can be initialized with specific **min/max length** (0 - 64 by default), **charset** it should use (printable ASCII by default), and **seed** for reproducing sequences (random seed by default), among other parameters.

Once initialized, it provides new `FuzzInput` every time you call its `next` method. Aside from the input itself, it contains metadata such as `seed` used and `iteration` of sequence stemming from this seed.

### `lib/runner/external_runner.rb`

Overseer of every target program execution. It must be initialized with the **path** to target binary. Specific **input mode** (`:stdin` -- default, `:file`, or `:argv`) can be selected in addition to **timeout** threshold.

Upon calling `run(fuzz_input)`, runner takes generated input, feeds it into target program binary and runs it, oversees the whole run and (if need be) kills the program if it timeouts. After the run, it collects and returns `RunResult`, which contains `exit_code`, `stdout`, `stderr`, `wall_time_ms`, and `timed_out` flag.

### `lib/oracle/*.rb`

This directory contains 3 different oracles -- `ASAN`/`ReturnCode`/`Timeout`-`Oracle` -- and `chain.rb`, which is the entrypoint we use to work with them and order their priority (ASAN\>TIMEOUT\>RC).

Each oracle looks for different things -- `Timeout` and `ReturnCode` oracles are straightforward (`Timeout` catches any results where `timed_out` flag is `true`, `ReturnCode` catches any results where `exit_code` is non-zero integer and is not timed out). `ASAN` matches Summary line in the `stderr` and matches stack/heap overflow.

We initialize chain with **timeout** threshold it passes to `TimeoutOracle` (this **timeout** should = **timeout** for the program we passed into runner). We can then call `classify(run_result,fuzz_input)`, which will return `Classification` struct (from one of the oracles, depends which one catches it) denoting what the result should be treated as. If no oracle caught it, it is taken as **passed/no bug**. To recognize what it is, `Classification` struct contains metadata:

  * `:status` (`:pass`, `:hang`, `:fail`)

  * `:oracle` (`:asan`, `:return_code`, `:timeout`, `nil` -- pass)

  * `:bug_info` -- info regarding bug (different for each oracle). `ASAN` reports file, line, and type of bug it caused (heap/stack overflow). `ReturnCode` just passes return code, and `Timeout` passes the threshold for timeout.

  * `:signature` -- string that deduplicator will later use to decide, if 2 `ASAN`/`ReturnCode`/`Timeout` crashes are the same bug instance or not. It is in format `[BUG_TYPE]:[BUG_INFO]` (ex. `asan:stack:myfile:12` or `rc:1`)

### `lib/results/deduplicator.rb`

Class which maintains a set of signatures of discovered bugs.

### `lib/results/results_store.rb` & `lib/results/stats_aggregator.rb`

Classes for writing out results for the whole campaign and individual crashes / hangs. I tried to make this match task description, but from the CI results it seems I did not, although I am almost 100% sure that the results it saves have same informational value, and when running with mock program and then going over the results (see `example_fuzz_run` dir), they seem to be correct.

### `/lib/minimize/ddmin.rb`

Delta-Debugging algorithm for input minimization. It contains the ddmin in `self.run(input_bytes:, bug_observer:)`, where `input_bytes:` param is the input we want to minimize.

`bug_observer:` param is boolean lambda function, which takes in substring from `input_bytes` and simply returns whether the substring causes currently targeted bug for minimization or not **AND** it reports any other bugs to the deduplicator. This is the reason we pass it as parameter into the `run` function -- we need to define it in the context where we also have deduplicator and from which we run the main campaign (`bin/fuzzer`)

### `lib/minimize/worker_pool.rb`

*Forking Server*. It spawns the minimizers processes, sets up IO, and cleans up after. It wraps `IO.select` so the main fuzzing loop can query stuff like free workers and new messages.

### `lib/cli/reporter.rb`

Pretty printer using `colorize` gem :).

### `lib/ipc/protocol.rb`

Communication between the parent fuzzer and the worker processes. Since this is over pipes (streams of bytes), I used a micro protocol with lenght-prefix. It takes a Ruby object, serializes it using `Marshal` (AI suggestion, I did not know of this), and prepends a 4-byte header indicating the size of the payload.

### `lib/config.rb` & `bin/fuzzer`

See **How it works** section


---

> Radek Cichra
