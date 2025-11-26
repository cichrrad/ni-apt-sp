# frozen_string_literal: true

module Oracle
  # Detects hangs
  # ASAN > TIMEOUT > RC
  class TimeoutOracle
    def initialize(threshold:)
      @threshold_ms = Integer(threshold)
    end

    def check(run_result, _fuzz_input)
      return nil unless run_result.timed_out

      Classification.new(
        status: :hang,
        oracle: :timeout,
        bug_info: @threshold_ms,
        signature: "timeout:#{@threshold_ms}"
      )
    end
  end
end
