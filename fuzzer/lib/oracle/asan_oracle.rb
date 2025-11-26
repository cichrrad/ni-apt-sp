# frozen_string_literal: true

module Oracle
  class ASANOracle
    # Had to split regex into 2 parts
    # because it used to capture
    # file and line of
    # ASAN src files, not
    # target binary

    KIND_REGEX = /AddressSanitizer: (stack|heap)-buffer-overflow/.freeze
    FRAME_REGEX = /^\s*#\d+.*\s+([^\s]+):(\d+)/.freeze

    def check(run_result, _fuzz_input)
      stderr = run_result.stderr
      return nil if stderr.nil? || stderr.empty?

      # decide heap/stack
      kind_match = KIND_REGEX.match(stderr)
      return nil unless kind_match

      kind = kind_match[1].to_sym

      # decide loc
      stderr.scan(FRAME_REGEX) do |match|
        # The file path
        file_path = match[0]
        # The line number
        line = match[1].to_i

        file = File.basename(file_path)
        # Skip ASAN code
        next if file_path.include?('libsanitizer') || file_path.include?('interceptors')

        info = { file: file, line: line, kind: kind }
        sig = "asan:#{kind}:#{file}:#{line}"

        return Classification.new(
          status: :fail,
          oracle: :asan,
          bug_info: info,
          signature: sig
        )
      end

      # If we found a 'kind' but no valid stack frame, we can't classify
      # because we cannot find the location
      nil
    end
  end
end
