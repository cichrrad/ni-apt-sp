# frozen_string_literal: true

require_relative 'timeout_oracle'
require_relative 'return_code_oracle'
require_relative 'asan_oracle'

# A standard result from the oracle chain.
#
# - status:     :pass or :fail or :hang
# - oracle:     :asan or :return_code or :timeout or nil
# - bug_info:   report of each bug
# - signature:  identifier for dedups (string with metadata)
Classification = Struct.new(:status, :oracle, :bug_info, :signature, keyword_init: true) do
  def self.pass
    new(status: :pass, oracle: nil, bug_info: nil, signature: nil)
  end

  def pass?
    status == :pass
  end

  def fail?
    status == :fail
  end

  def hang?
    status == :hang
  end
end

module Oracle
  # Chain of responsibility
  # https://en.wikipedia.org/wiki/Chain-of-responsibility_pattern
  # [Result] --> ASAN --> TIMEOUT --> RC --> [PASS]
  class Chain
    def initialize(run_timeout_ms:)
      @run_timeout_ms = run_timeout_ms

      @oracles = [
        Oracle::ASANOracle.new,
        Oracle::TimeoutOracle.new(threshold: @run_timeout_ms),
        Oracle::ReturnCodeOracle.new
      ]
    end

    def classify(run_result, fuzz_input)
      # run in order of priorities
      @oracles.each do |orcl|
        classification = orcl.check(run_result, fuzz_input)

        # first non-nil return is top priority oracle
        return classification if classification && !classification.pass?
      end

      # if no oracle found their issue, pass
      Classification.pass
    end
  end
end
