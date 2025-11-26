# Random Fuzzer - NI-APT task 2

I've implemented random fuzzer task in Ruby. As per the Task 1 feedback (+ also because as far as I understand, this task is foundation for future tasks), I've actually planned ahead in regards of file structure to hopefully keep the directory somewhat sane, and most importantly, expandable for future tasks. I've also tried to stay away from helper bash scripts and such, aiming at implementing everything in Ruby or Makefile 

This actually taught me few nice things (explicitly, I found out that ruby formatting is strangely opinionated -- if you've used `rubocop`, you know... -- and that `rspec` explores `spec/` directory if it is present and runs all spec files in it, which is awesome! In addition to that, I found out about `pry` gem which is very nice for debugging).

## Testing

Code coverage of my tests are **94.95%**.

## Hand-in / grader notes

I've had some struggles with the pipeline runs, but I think my fuzzer is correct so I wanted to just note some things I tried to show that.

I've run the pipeline empty so that I got my hands on the inputs that trigger bugs. Then I modified my generator to only produce these inputs in loop so that I can guarantee they are found. Once I did this, I was able to verify correctness of the other parts of my fuzzer in the runner, and so I did (see [pipeline log](https://gitlab.fit.cvut.cz/cichrrad/apt-2025-cichra/-/jobs/1385142)). This way I was able to confirm that the **fuzzer passes** all the parts of the pipeline, **if it finds the inputs. So why it didn't?**

For the large inputs, it is because I simply don't generate such long inputs. My default range is printable ASCII C strings 1 to 128 chars. If there is input 1001 chars long, I won't find it. I could generate inputs in range 1 to, say 2000, but that decreases probability of smaller bug inducing inputs, as it inflates the *space of possible inputs* a lot. 

*(Unchecked and possibly very bad math below)*

Even if I generated **exactly** 1001 chars long input, my fuzzer tops at ~35k (MAY NOT EVEN BE UNIQUE) inputs in the 600 seconds allowed. so I explore (35000/95^1001) of all the inputs, which is roughly 0.00...(~1973 zeroes)69 % of the inputs explored. Since I don't know how the grader works inside, it is very much possible that many inputs trigger the desired bug, but it need to be A LOT to trigger it using random fuzzing in 600s (Even if my fuzzer is arguably slow, I'd be first one to admit that -- Ruby is not the most performant language out there and, more importantly, my code may very well be a mess :))

---
> NOTE: -- Sorry the README.md is a bit chaotic, I probably won't have time to polish it as I had with the first task
## AI 

As per task directions, I disclose I was using AI during this task, but I believe it was within bounds where it is more than fine to do so. I did not let it "run wild" and just give me code files for me to paste in (thus there are no line `a` to `b` tagged as AI) -- instead, I used it as a tool to help me clarify how I want to design parts of code, how to make them work together in the long run etc. It served a "consultant" role in a sense, where I used it as a wall to bounce ideas off. It provided second opinion / *expertise* (aka being trained on half the internet) and chimed in for suggestions when I was not sure about something and asked it.

If the need arises, I'd be happy to clarify, but I want to make it clear that **I read, thought about, understood and therefore wrote** every line of code in the program (I hope my comments make it clear) -- so I can explain it while it sits fresh in my mind.


## Project structure

Project root (`fuzzer`) has following subdirectories:

* `lib` -- `.rb` source files for all the fuzzer components (split into subdirectories by purpose/what I thought was fine).

* `spec` -- directory with `rspec` tests. Its structure copies `lib` directory, so its more than clear to see what spec maps to what component. As per Task 1 feedback (and to not go mad by debugging end-to-end program runs), I've tried to test each component separately to verify all interesting scenarios are handled gracefully and as I would want. Regarding end-to-end tests, I struggled with coming up with a way to test the binary file without actually running a campaign, so I at least ran it on mock binary which produces various bugs and sanity checked that they were caught and the stats look fine (see `example_fuzz_run`).

* `target_programs` -- has `src` and empty `binary` subdirectories. It containes mock `.c` programs that are used in `spec` testing (specifically in runner tests). As per Task 1, binaries for them are not present and will be compiled upon running tests, if they are missing.

## How it works

>**TL:DR** -- Fuzzer feeds generated inputs into runner -> runner runs target binary with the input -> runner captures output (return code, data streams etc.) -> outputs are handed to oracle chain for classification -> classified output is deduplicated & its input is minimized (if its the first time we see it) --> we update bug & fuzz campaign statistic

Fuzzer has multiple components (described below) and they all come together in `bin/fuzzer`. When campaign is started by entering something like:
```
export FUZZED_PROG=target_programs/binary/mock && export RESULT_FUZZ=./example_fuzz_run && export INPUT=stdin && export MINIMIZE=1 && export TIMEOUT=300 && make run
```
Fuzzer controller binary `bin/fuzzer` is called. During initialization, it first validates it received all the required env vars (in and out paths) and captures the other ones (this is handled by `lib/config.rb`). 

After this (still during initialization), we create instances of all the objects (fuzzer components) we will use during the campaign -- these include mainly `@generator`,`@runner`,`@oracle`,`@deduplicator` etc. These correspond to fuzzer components and are described below.

A high-level picture of what the fuzzer campaign will do is visible in the `run` method:

```Ruby
 def run
    setup_signal_traps
    spawn_timeout_thread
    spawn_minimizer_thread # actually spawns 4 threads
    run_main_fuzzing_loop
    shutdown
  end
```

So the fuzzer will first basically just setup graceful shutdown (`setup_signal_traps`), spawn timeout thread which will sleep for the time given by the `TIMEOUT` env var - 10, then stop the campaign.

In the meantime (until we kill the program or timeout), there are 1+4 threads which do all the work -- `spawn_minimizer_thread` spawns threads on which we minimize inputs of found bugs. `run_main_fuzzing_loop` on the other hand just pipes generated inputs into runner all the time. These threads interface via queue (thread-safe in Ruby) -- main thread pushes any new bugs, and minimize threads try to pop and whenever they can they minimize what they popped. When we are ending campaign, we push `nil` into the queue for each minimize thread so that they end gracefully -- If they are currently working and don't see their `nil` before program dies, they are still killed because our fuzzer exits, but we will lose whatever they were currently minimizing (although we would probably not save partial result anyway?).

Once program is killed / `TIMEOUT` is nearing, we save reports and wrap it up with `shutdown`.

## Example campaign

Can be found in `example_fuzz_run`. It was run with the command shown above (mock binary has to be compiled with `make build` first):

```
export FUZZED_PROG=target_programs/binary/mock && export RESULT_FUZZ=./example_fuzz_run && export INPUT=stdin && export MINIMIZE=1 && export TIMEOUT=300 && make run
```

I went over this as a sanity check when my pipeline did not work, and It seems to me that it is correct, as specific inputs trigger specific bugs (corresponding to `mock.c` logic) as expected + number of crashes and hangs match (5+1) and location in code do as well.

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

### `lib/config.rb` & `bin/fuzzer`

See **How it works** section
