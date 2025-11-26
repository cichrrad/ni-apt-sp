# frozen_string_literal: true

require_relative '../../spec_helper'
require_relative '../../../lib/runner/external_runner'

describe Runner::ExternalRunner do
  BIN_DIR = File.expand_path('../../../target_programs/binary', __dir__) # rubocop:disable Lint/ConstantDefinitionInBlock

  def bin_path(name)
    File.join(BIN_DIR, name)
  end

  # sanity check binaries existr
  before(:all) do
    @binaries_exist = %w[echo_stdin echo_argv echo_file exit_42 write_stderr sleep_3].all? do |bin|
      File.executable?(bin_path(bin))
    end
  end

  # skip missing binaries
  around(:each) do |example|
    if @binaries_exist
      example.run
    else
      skip "Test binaries not compiled. Run 'make test_targets'" # TODO!!!
    end
  end

  context ':stdin mode tests' do
    let!(:runner) { described_class.new(target_path: bin_path('echo_stdin'), mode: :stdin) }

    it 'piping' do
      res = runner.run('hello stdin')
      expect(res.stdout).to eq('hello stdin'.b)
      expect(res.exit_code).to eq(0)
      expect(res.timed_out).to be(false)
    end

    it 'c string safe' do
      # .b forces ASCII-8BIT encoding
      input_bytes = "hello\x00world\xFF".b
      res = runner.run(input_bytes)

      expect(res.stdout.encoding).to eq(Encoding::ASCII_8BIT)
      expect(res.stdout.bytes).to eq(input_bytes.bytes)
      expect(res.exit_code).to eq(0)
    end
  end

  context ':file mode tests' do
    let!(:runner) { described_class.new(target_path: bin_path('echo_file'), mode: :file) }

    it 'writes input to a temp file and captures stdout' do
      res = runner.run('hello file')
      expect(res.stdout).to eq('hello file'.b)
      expect(res.exit_code).to eq(0)
    end
  end

  context ':argv mode tests' do
    let!(:runner) { described_class.new(target_path: bin_path('echo_argv'), mode: :argv) }

    it 'passes input as argv[1] and captures stdout' do
      res = runner.run('hello argv')
      expect(res.stdout).to eq('hello argv'.b)
      expect(res.exit_code).to eq(0)
    end
  end

  context 'with exit code handling' do
    it 'captures non-zero exit codes' do
      runner = described_class.new(target_path: bin_path('exit_42'), mode: :stdin)
      res = runner.run('')
      expect(res.exit_code).to eq(42)
      expect(res.timed_out).to be(false)
    end
  end

  context 'with stderr handling' do
    it 'captures stderr output' do
      runner = described_class.new(target_path: bin_path('write_stderr'), mode: :stdin)
      res = runner.run('')
      expect(res.stderr).to eq('this is an error message')
      expect(res.exit_code).to eq(1) # against the binary ret
    end
  end

  context 'Timeout tests' do
    it 'kills after timeout' do
      runner = described_class.new(target_path: bin_path('sleep_3'), mode: :stdin, run_timeout_ms: 100)
      res = runner.run('')

      expect(res.timed_out).to be(true)
      expect(res.exit_code).to be_nil

      # if timed out, time should be
      # a little bit more (due to grace
      # period before shooting its head off)
      expect(res.wall_time_ms).to be > 90
      expect(res.wall_time_ms).to be < 250
    end
  end
end
