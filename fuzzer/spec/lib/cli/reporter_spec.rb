# frozen_string_literal: true

require_relative '../../spec_helper'
require_relative '../../../lib/cli/reporter'
require_relative '../../../lib/oracle/chain' # for Classification struct

describe CLI::Reporter do
  let(:reporter) { described_class.new }

  def capture_stdout
    original_stdout = $stdout
    $stdout = StringIO.new
    yield
    $stdout.string
  ensure
    $stdout = original_stdout
  end

  context 'Startup logging' do
    let(:config) do
      instance_double('Config',
                      fuzzed_program: '/bin/ls',
                      minimize_enabled?: true)
    end

    it 'prints startup summary' do
      output = capture_stdout do
        reporter.log_startup(config, 4)
      end

      expect(output).to include('Fuzzer Starting')
      expect(output).to include('/bin/ls')
      expect(output).to include('4')
    end
  end

  context 'Bug reporting' do
    let(:classification) do
      Classification.new(
        status: :fail,
        oracle: :asan,
        bug_info: { kind: :stack },
        signature: 'asan:stack:overflow.c:12'
      )
    end

    it 'logs new bug discovery' do
      output = capture_stdout do
        reporter.log_new_bug(classification)
      end

      expect(output).to include('NEW FAILURE FOUND')
      expect(output).to include('asan:stack:overflow.c:12')
      expect(output).to include('Queued for minimization')
    end

    it 'logs minimization progress' do
      output = capture_stdout do
        reporter.log_minimization_done(classification, 100, 10)
      end

      expect(output).to include('Minimization Complete')
      expect(output).to include('100 bytes -> 10 bytes')
    end
  end

  context 'General logging' do
    it 'formats info messages' do
      output = capture_stdout { reporter.log_info('Test message') }
      expect(output).to include('[INFO] Test message')
    end

    it 'formats error messages' do
      output = capture_stdout { reporter.log_error('Bad thing happened') }
      expect(output).to include('[ERROR] Bad thing happened')
    end
  end
end
