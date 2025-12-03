# frozen_string_literal: true

require 'json'

module Results
  # Collects and saves all fuzzing campaign statistics.
  class StatsAggregator
    attr_writer :current_queue_size, :current_coverage

    def initialize(fuzzed_program:, fuzzer_name: 'FuzzyWuzzy')
      raise ArgumentError, 'fuzzer_name cannot be empty' if fuzzer_name.nil? || fuzzer_name.empty?

      @fuzzer_name = fuzzer_name
      @fuzzed_program = fuzzed_program

      # General run counters
      @nb_runs = 0
      @nb_failed_runs = 0
      @nb_hanged_runs = 0
      @execution_times_ms = [] # For per-run timings

      # Unique failure tracking
      @nb_unique_failures = 0 # Post-minimization
      @minimization_before = 0 # Pre-minimization

      # Minimization stats
      @minimization_steps = []
      @minimization_times_ms = []

      @lock = Mutex.new
    end

    # Called on every single run
    def record_run(run_result, classification)
      @lock.synchronize do
        @nb_runs += 1
        @execution_times_ms << run_result.wall_time_ms
        @nb_failed_runs += 1 if classification.fail?
        @nb_hanged_runs += 1 if classification.hang?
      end
    end

    # Called only when a new sig is found.
    def record_new_discovery
      @lock.synchronize do
        @minimization_before += 1
      end
    end

    # Called after a failure report is saved (post-minimization).
    def record_saved_report
      @lock.synchronize do
        @nb_unique_failures += 1
      end
    end

    # Called after minimization completes.
    def record_minimization(min_result)
      @lock.synchronize do
        @minimization_steps << min_result.nb_steps
        @minimization_times_ms << min_result.exec_time_ms
      end
    end

    # Final save
    def save(path)
      report = build_report
      File.write(path, JSON.pretty_generate(report))
    end

    private

    def build_report
      @lock.synchronize do
        {
          fuzzer_name: @fuzzer_name,
          fuzzed_program: @fuzzed_program,
          nb_runs: @nb_runs,
          nb_failed_runs: @nb_failed_runs,
          nb_hanged_runs: @nb_hanged_runs,
          nb_queued_seeds: @current_queue_size || 0,
          coverage: @current_coverage || 0,
          execution_time: calculate_timings(@execution_times_ms),
          nb_unique_failures: @nb_unique_failures,
          minimization: calculate_minimization_stats
        }
      end
    end

    def calculate_timings(times)
      return { average: 0, median: 0, min: 0, max: 0 } if times.empty?

      {
        average: times.sum.to_f / times.length,
        median: median(times),
        min: times.min,
        max: times.max
      }
    end

    def calculate_minimization_stats
      avg_steps = if @minimization_steps.empty?
                    0
                  else
                    @minimization_steps.sum.to_f / @minimization_steps.length
                  end

      {
        before: @minimization_before,
        avg_steps: avg_steps.to_i,
        execution_time: calculate_timings(@minimization_times_ms)
      }
    end

    def median(array)
      return 0 if array.empty?

      sorted = array.sort
      len = sorted.length
      mid = (len - 1) / 2.0
      (sorted[mid.floor] + sorted[mid.ceil]) / 2.0
    end
  end
end
