# frozen_string_literal: true

require_relative '../../spec_helper'
require_relative '../../../lib/runner/external_runner' # For RunResult
require_relative '../../../lib/oracle/asan_oracle'
require_relative '../../../lib/oracle/chain' # For Classification

describe Oracle::ASANOracle do
  let(:oracle) { described_class.new }
  let(:empty_input) { FuzzInput.new(bytes: ''.b) }

  # Helper to create a fake RunResult
  def fake_result(stderr: '', exit_code: 0, timed_out: false)
    RunResult.new(
      stderr: stderr.b, # Ensure bytes
      stdout: ''.b,
      exit_code: exit_code,
      timed_out: timed_out,
      wall_time_ms: 10
    )
  end

  context 'with ASAN stack-buffer-overflow' do
    let(:stderr) do
      <<~ASAN
        ==123==ERROR: AddressSanitizer: stack-buffer-overflow on address 0x7ff...
        READ of size 8 at 0x7ff... thread T0
            #0 0x4f... in main /app/src/overflow.c:12

        AddressSanitizer: stack-buffer-overflow on address 0x7ff... at /app/src/overflow.c:12 (fuzz_target+0x4f...)

        SUMMARY: AddressSanitizer: stack-buffer-overflow /app/src/overflow.c:12 in main
        ==123==ABORTING
      ASAN
    end
    let(:result) { fake_result(stderr: stderr, exit_code: 1) }

    it 'detects the crash' do
      classification = oracle.check(result, empty_input)
      expect(classification).not_to be_nil
      expect(classification.status).to eq(:fail)
      expect(classification.oracle).to eq(:asan)
    end

    it 'extracts the correct bug_info' do
      info = oracle.check(result, empty_input).bug_info
      expect(info[:kind]).to eq(:stack)
      expect(info[:file]).to eq('overflow.c')
      expect(info[:line]).to eq(12)
    end

    it 'generates the correct signature' do
      sig = oracle.check(result, empty_input).signature
      expect(sig).to eq('asan:stack:overflow.c:12')
    end
  end

  context 'with ASAN heap-buffer-overflow' do
    let(:stderr) do
      <<~ASAN
        ==456==ERROR: AddressSanitizer: heap-buffer-overflow on address 0x60...
        READ of size 1 at 0x60... thread T0
            #0 0x4c... in main /src/heap_bug.c:45

        SUMMARY: AddressSanitizer: heap-buffer-overflow /src/heap_bug.c:45 in main
        ==456==ABORTING
      ASAN
    end
    let(:result) { fake_result(stderr: stderr, exit_code: 1) }

    it 'detects the crash' do
      classification = oracle.check(result, empty_input)
      expect(classification).not_to be_nil
      expect(classification.status).to eq(:fail)
      expect(classification.oracle).to eq(:asan)
    end

    it 'extracts the correct bug_info' do
      info = oracle.check(result, empty_input).bug_info
      expect(info[:kind]).to eq(:heap)
      expect(info[:file]).to eq('heap_bug.c')
      expect(info[:line]).to eq(45)
    end
  end

  context 'with no ASAN error' do
    it 'returns nil for empty stderr' do
      result = fake_result(stderr: '', exit_code: 0)
      expect(oracle.check(result, empty_input)).to be_nil
    end

    it 'returns nil for non-ASAN stderr' do
      result = fake_result(stderr: 'This is just some warning', exit_code: 0)
      expect(oracle.check(result, empty_input)).to be_nil
    end

    it 'returns nil for a clean run' do
      result = fake_result(exit_code: 0)
      expect(oracle.check(result, empty_input)).to be_nil
    end
  end
end
