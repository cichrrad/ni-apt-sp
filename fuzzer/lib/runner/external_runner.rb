# frozen_string_literal: true

require 'tempfile'
require 'pry'

# Single run result struct
RunResult = Struct.new(:exit_code, :stdout, :stderr, :wall_time_ms, :timed_out, keyword_init: true)

module Runner
  # ExternalRunner executes toy program with generated input.
  # - mode : :stdin, :argv, or :file (first argument)
  # - run_timeout_ms : per-run time limit
  # - work_dir : optional child dir for the target (nil => current dir)
  # - keep_files : if true in :file mode, don't delete the temp file we used to pass input
  class ExternalRunner
    DEFAULT_TIMEOUT_MS = 5_000

    def initialize(target_path:, mode: :stdin, run_timeout_ms: DEFAULT_TIMEOUT_MS, work_dir: nil, keep_files: false)
      raise ArgumentError, 'mode must be :stdin, :file, or :argv' unless %i[stdin file argv].include?(mode)

      @target_path   = String(target_path)
      @mode          = mode.to_sym
      @run_timeout_ms = Integer(run_timeout_ms)
      @work_dir      = work_dir
      @keep_files    = !!keep_files
    end

    def run(fuzz_input)
      bytes = extract_bytes(fuzz_input)

      tempfile = nil
      argv = [@target_path]
      case @mode
      when :file
        # TODO: -- maybe make it so that
        # we can reuse tempfile ?
        tempfile = create_input_file(bytes)
        argv << tempfile.path
      when :argv
        argv << bytes
      end

      # Pipes for child's stdio
      stdin_r,  stdin_w  = IO.pipe
      stdout_r, stdout_w = IO.pipe
      stderr_r, stderr_w = IO.pipe

      pid = nil
      status = nil
      timed_out = false

      begin
        spawn_opts = {
          in: stdin_r,
          out: stdout_w,
          err: stderr_w,
          pgroup: true # makes child leader of their own group
          # ==> -pid is the groups pid, so we can wipe it and
          # any grandchildren
        }
        spawn_opts[:chdir] = @work_dir if @work_dir

        # Spawn child
        # https://docs.ruby-lang.org/en/3.4/Process.html
        pid = Process.spawn(*argv, spawn_opts)

        # Piping setup
        stdin_r.close
        stdout_w.close
        stderr_w.close
        stdin_w.binmode
        stdout_r.binmode
        stderr_r.binmode

        # Feed generated input
        # (for :file it was passed as
        # file to argv)
        stdin_w.write(bytes) if @mode == :stdin
        stdin_w.close # EOI

        out_buf = String.new(encoding: Encoding::ASCII_8BIT)
        err_buf = String.new(encoding: Encoding::ASCII_8BIT)

        # Collect stdout/stderr on dedicated threads
        # (otherwise we might deadlock)
        # https://docs.ruby-lang.org/en/3.4/Thread.html
        out_t = Thread.new { read_stream(stdout_r, out_buf) }
        err_t = Thread.new { read_stream(stderr_r, err_buf) }

        # https://docs.ruby-lang.org/en/3.4/Process.html#method-c-clock_gettime
        # TLDR -- CLOCK_MONOTONIC is always
        # correct
        t0 = Process.clock_gettime(Process::CLOCK_MONOTONIC)
        loop do
          # https://docs.ruby-lang.org/en/3.4/Process.html#method-c-wait
          # TLDR -- WNOHANG flag makes it NOT BLOCK
          # which we need to update elapsed time
          # and see if we should time out or not
          wpid, stat = Process.waitpid2(pid, Process::WNOHANG)
          # non-nil once completed
          if wpid
            status = stat
            break
          end
          # delta
          elapsed_ms = ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - t0) * 1000.0).to_i

          # TIMEOUT branch
          if elapsed_ms >= @run_timeout_ms
            timed_out = true
            # Ask nicely first
            safe_kill('TERM', -pid)
            # Let child get settle their
            # things
            sleep 0.05
            # No longer ask nicely
            safe_kill('KILL', -pid)
            begin
              # here we block
              _, status = Process.waitpid2(pid) # first arg is pid
            rescue Errno::ECHILD
              # bad practice
            end
            break
          end
          # anti busy wait
          # de-facto sets time resolution
          sleep 0.01
        end

        out_t.join
        err_t.join

        stdout = out_buf.force_encoding(Encoding::ASCII_8BIT)
        stderr = err_buf.force_encoding(Encoding::ASCII_8BIT)
        # HERE we stop timing (after pipes are drained)
        wall_ms = ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - t0) * 1000.0).to_i

        RunResult.new(
          exit_code: status&.exitstatus, # nil if killed by signal/timeout
          stdout: stdout,
          stderr: stderr,
          wall_time_ms: wall_ms,
          timed_out: timed_out
        )
      # 'finally' -- always try to clean up and sanity check
      ensure
        # File descriptor closing
        [stdin_w, stdout_r, stderr_r].each { |io| begin io&.close unless io&.closed?; rescue StandardError; end }
        if pid
          begin
            # If the child is still around
            safe_kill('KILL', -pid)
            begin
              Process.waitpid(pid)
            rescue StandardError
              nil
            end
          rescue StandardError
            # bad practice
          end
        end
        if tempfile && !@keep_files
          begin
            tempfile.close!
          rescue StandardError
            # bad practice
          end
        end
      end
    end

    private

    # pull bytes out of anything with 'bytes' method
    def extract_bytes(obj)
      if obj.is_a?(String)
        obj.dup.force_encoding(Encoding::ASCII_8BIT)
      elsif obj.respond_to?(:bytes) && obj.bytes.is_a?(String)
        obj.bytes.dup.force_encoding(Encoding::ASCII_8BIT)
      else
        raise ArgumentError, 'runner expects a String of bytes or an object with #bytes returning String'
      end
    end

    def create_input_file(bytes)
      # Ruby has cool stuff
      # https://docs.ruby-lang.org/en/3.4/Tempfile.html
      tf = Tempfile.new(['apt_input_', '.bin'], @work_dir || Dir.tmpdir, binmode: true)
      tf.write(bytes)
      tf.flush
      tf.rewind
      tf
    end

    def read_stream(io, buffer)
      loop do
        chunk = io.readpartial(4096)
        buffer << chunk
      rescue EOFError
        break
      rescue IOError
        break
      end
    ensure
      begin
        io.close unless io.closed?
      rescue StandardError
        # bad practice
      end
    end

    def safe_kill(sig, pid_or_pgid)
      Process.kill(sig, pid_or_pgid)
    rescue Errno::ESRCH
      # already gone
    rescue StandardError
      # ignore
    end
  end
end
