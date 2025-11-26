# frozen_string_literal: true

require_relative '../../spec_helper'
require_relative '../../../lib/runner/external_runner' # For RunResult
require_relative '../../../lib/oracle/return_code_oracle'
require_relative '../../../lib/oracle/chain' # For Classification

describe Oracle::ReturnCodeOracle do
  let(:oracle) { described_class.new }
  let(:empty_input) { FuzzInput.new(bytes: ''.b) }

  def fake_result(stderr: '', exit_code: 0, timed_out: false)
    RunResult.new(
      stderr: stderr.b,
      stdout: ''.b,
      exit_code: exit_code,
      timed_out: timed_out,
      wall_time_ms: 10
    )
  end

  it 'Recognizes non-zero RC' do
    result = fake_result(exit_code: 42)
    classification = oracle.check(result, empty_input)

    expect(classification).not_to be_nil
    expect(classification.status).to eq(:fail)
    expect(classification.oracle).to eq(:return_code)
    expect(classification.bug_info).to eq(42)
    expect(classification.signature).to eq('rc:42')
  end

  it 'Lets RC=0 pass' do
    result = fake_result(exit_code: 0)
    classification = oracle.check(result, empty_input)
    expect(classification).to be_nil
  end

  # NOTE : -- If order of our oracles holds and is not flawed
  # nothing with nil RC should slip through the previous
  # oracles in the chain, so this should never
  # happen
  it 'Returns nil for nil exit code' do
    result = fake_result(exit_code: nil)
    classification = oracle.check(result, empty_input)
    expect(classification).to be_nil
  end

  # Same as above
  it 'returns nil for timeout' do
    result = fake_result(timed_out: true, exit_code: nil)
    classification = oracle.check(result, empty_input)
    expect(classification).to be_nil
  end
end
