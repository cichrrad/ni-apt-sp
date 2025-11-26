# frozen_string_literal: true

require_relative '../../spec_helper'
require_relative '../../../lib/runner/external_runner' # For RunResult
require_relative '../../../lib/oracle/chain'

describe Oracle::Chain do
  let(:chain) { described_class.new(run_timeout_ms: 5000) }
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

  let(:asan_stderr) do
    <<~ASAN
      ==456==ERROR: AddressSanitizer: heap-buffer-overflow on address 0x60...
      READ of size 1 at 0x60... thread T0
          #0 0x5555555555a8 in main /src/heap_bug.c:45
          #1 0x... in __libc_start_main ...

      SUMMARY: AddressSanitizer: heap-buffer-overflow /src/heap_bug.c:45 in main
      ==456==ABORTING
    ASAN
  end

  context 'Priority tests' do
    it 'Prioritizes ASAN over Timeout' do
      # timeout AND HBO
      result = fake_result(stderr: asan_stderr, timed_out: true, exit_code: nil)
      classification = chain.classify(result, empty_input)

      expect(classification.oracle).to eq(:asan)
      expect(classification.status).to eq(:fail)
    end

    it 'prioritizes ASAN over ReturnCode' do
      # non-zero RC AND HBO
      result = fake_result(stderr: asan_stderr, exit_code: 69)
      classification = chain.classify(result, empty_input)

      expect(classification.oracle).to eq(:asan)
      expect(classification.signature).to start_with('asan:heap:')
    end

    it 'prioritizes Timeout over ReturnCode' do
      # non-zero RC AND Timeout
      # no idea how this could even happen (when we timeout,
      # RC is nil)
      result = fake_result(timed_out: true, exit_code: 1)
      classification = chain.classify(result, empty_input)

      expect(classification.oracle).to eq(:timeout)
      expect(classification.status).to eq(:hang)
    end
  end

  context 'Oracle classification' do
    it 'ASAN' do
      result = fake_result(stderr: asan_stderr, exit_code: 1)
      classification = chain.classify(result, empty_input)
      expect(classification.oracle).to eq(:asan)
    end

    it 'Timeout' do
      result = fake_result(timed_out: true)
      classification = chain.classify(result, empty_input)
      expect(classification.oracle).to eq(:timeout)
    end

    it 'RC' do
      result = fake_result(exit_code: 42)
      classification = chain.classify(result, empty_input)
      expect(classification.oracle).to eq(:return_code)
      expect(classification.bug_info).to eq(42)
    end

    it 'Pass' do
      result = fake_result(exit_code: 0)
      classification = chain.classify(result, empty_input)

      expect(classification.status).to eq(:pass)
      expect(classification.pass?).to be(true)
    end
  end
end
