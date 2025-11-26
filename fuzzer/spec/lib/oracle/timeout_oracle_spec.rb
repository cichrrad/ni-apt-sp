# frozen_string_literal: true

require_relative '../../spec_helper'
require_relative '../../../lib/runner/external_runner' # For RunResult
require_relative '../../../lib/oracle/timeout_oracle'
require_relative '../../../lib/oracle/chain' # For Classification

describe Oracle::TimeoutOracle do
  let(:threshold) { 5000 } # ms
  let(:oracle) { described_class.new(threshold: threshold) }
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

  it 'Recognizes hang from timeout flag' do
    result = fake_result(timed_out: true)
    classification = oracle.check(result, empty_input)

    expect(classification).not_to be_nil
    expect(classification.status).to eq(:hang)
    expect(classification.oracle).to eq(:timeout)
    expect(classification.bug_info).to eq(threshold)
    expect(classification.signature).to eq("timeout:#{threshold}")
  end

  it 'Ignores runs without timeout' do
    result = fake_result(timed_out: false)
    classification = oracle.check(result, empty_input)
    expect(classification).to be_nil
  end

  it 'Ignores RC if not timeout' do
    result = fake_result(timed_out: false, exit_code: 1)
    classification = oracle.check(result, empty_input)
    expect(classification).to be_nil
  end
end
