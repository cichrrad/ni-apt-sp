# frozen_string_literal: true

require_relative '../spec_helper'
require 'tempfile'
require 'fileutils'

describe 'Config' do
  # Reference to the original ENV
  let(:original_env) { ENV.to_h }

  # Clean up constants and ENV after each test
  after(:each) do
    Object.send(:remove_const, :Config) if Object.const_defined?(:Config)
    ENV.replace(original_env)
  end

  # Dummy .exe to test target prog
  def with_dummy_executable
    Tempfile.create(['test_prog', '.exe']) do |f|
      f.close
      FileUtils.chmod(0o755, f.path) # Make it executable
      yield f.path
    end
  end

  # Dummy results dir
  def with_dummy_result_dir(&block)
    Dir.mktmpdir(&block)
  end

  # load config with fake env vars
  def load_config_with_env(mock_env)
    ENV.update(mock_env)
    # re-load to re-evaluate with new fake env
    load File.expand_path('../../lib/config.rb', __dir__)
  end

  context 'Valid ENV vars tests' do
    it 'Passes validate! and sets correct values' do
      with_dummy_executable do |prog_path|
        with_dummy_result_dir do |result_dir|
          mock_env = {
            'FUZZED_PROG' => prog_path,
            'RESULT_FUZZ' => result_dir,
            'INPUT' => 'file',
            'MINIMIZE' => '1'
          }
          load_config_with_env(mock_env)

          expect { Config.validate! }.not_to raise_error
          expect(Config.fuzzed_program).to eq(prog_path)
          expect(Config.result_dir).to eq(result_dir)
          expect(Config.input_mode).to eq(:file)
          expect(Config.minimize_enabled?).to be(true)
          expect(Config.fuzzer_name).not_to be_empty
        end
      end
    end
  end

  context 'Default ENV vars tests' do
    it 'passes validate! and sets correct defaults' do
      with_dummy_executable do |prog_path|
        with_dummy_result_dir do |result_dir|
          mock_env = {
            'FUZZED_PROG' => prog_path, # no default
            'RESULT_FUZZ' => result_dir, # no default
            'INPUT' => nil,
            'MINIMIZE' => nil
          }
          load_config_with_env(mock_env)

          expect { Config.validate! }.not_to raise_error
          expect(Config.input_mode).to eq(:stdin) # Default
          expect(Config.minimize_enabled?).to be(true) # Default
        end
      end
    end
  end

  context 'MINIMIZE=0 tests' do
    it 'sets minimize_enabled? to false' do
      with_dummy_executable do |prog_path|
        with_dummy_result_dir do |result_dir|
          mock_env = {
            'FUZZED_PROG' => prog_path,
            'RESULT_FUZZ' => result_dir,
            'MINIMIZE' => '0'
          }
          load_config_with_env(mock_env)

          expect(Config.minimize_enabled?).to be(false)
        end
      end
    end
  end

  context 'Invalid ENV vars tests' do
    it 'raises FUZZED_PROG is not set' do
      mock_env = { 'RESULT_FUZZ' => '/tmp' }
      # make sure it is not set
      ENV.delete('FUZZED_PROG')
      expect do
        load_config_with_env(mock_env)
      end.to raise_error(KeyError, /key not found: "FUZZED_PROG"/)
    end

    it 'raises if FUZZED_PROG is not executable' do
      with_dummy_result_dir do |result_dir|
        mock_env = {
          'FUZZED_PROG' => '/tmp/not/a/real/file',
          'RESULT_FUZZ' => result_dir
        }
        load_config_with_env(mock_env)
        expect { Config.validate! }.to raise_error("ERROR: FUZZED_PROG '/tmp/not/a/real/file' not found.")
      end
    end

    it 'raises if RESULT_FUZZ is not set' do
      mock_env = { 'FUZZED_PROG' => '/bin/true' }
      ENV.delete('RESULT_FUZZ')
      expect do
        load_config_with_env(mock_env)
      end.to raise_error(KeyError, /key not found: "RESULT_FUZZ"/)
    end

    it 'raises if RESULT_FUZZ write fails' do
      # this will fail if you run in sudo
      # (WHY WOULD YOU THOUGH????)
      with_dummy_executable do |prog_path|
        mock_env = {
          'FUZZED_PROG' => prog_path,
          'RESULT_FUZZ' => '/root/thisshouldbeunwritable/dir'
        }
        load_config_with_env(mock_env)

        allow(FileUtils).to receive(:mkdir_p).and_raise(SystemCallError.new('Permission denied', 13))
        expect { Config.validate! }.to raise_error(/Could not create result directory/)
      end
    end
  end
end
