# frozen_string_literal: true

module Oracle
  # Detects a non-zero exit code.
  # ASAN > TIMEOUT > RC
  class ReturnCodeOracle
    def check(run_result, _fuzz_input)
      # NOTE: -- This might let something slide
      return nil if run_result.exit_code.nil?

      return nil if run_result.exit_code.zero?

      code = run_result.exit_code
      Classification.new(
        status: :fail,
        oracle: :return_code,
        bug_info: code,
        signature: "rc:#{code}"
      )
    end
  end
end
