# frozen_string_literal: true

require_relative '../../spec_helper'
require 'fileutils'
require 'tmpdir'
require 'json'

# For fake results
require_relative '../../../lib/runner/external_runner'
require_relative '../../../lib/oracle/chain'
require_relative '../../../lib/minimize/ddmin'

require_relative '../../../lib/results/results_store'

describe Results::ResultsStore do
  let(:tmp_root_dir) { @tmp_root_dir }
  let(:store) { described_class.new(root_dir: tmp_root_dir) }

  # Dummy dir
  around(:each) do |example|
    Dir.mktmpdir do |dir|
      @tmp_root_dir = dir
      example.run
    end
  end

  # Fake crash clas.
  let(:crash_class) do
    Classification.new(
      status: :fail,
      oracle: :asan,
      bug_info: { file: 'a.c', line: 10, kind: :heap },
      signature: 'asan:heap:a.c:10'
    )
  end
  # fake hang
  let(:hang_class) do
    Classification.new(
      status: :hang,
      oracle: :timeout,
      bug_info: 250,
      signature: 'timeout:250'
    )
  end

  let(:run_result) { RunResult.new(wall_time_ms: 123) }

  let(:min_result) do
    Minimizer::Ddmin::MinimizationResult.new(
      nb_steps: 50,
      exec_time_ms: 2000
    )
  end

  let(:minimized_input) { 'A'.b }

  let(:unminimized_size) { 100 }

  context 'Init tests' do
    it 'creates subdirs' do
      store # Initialize
      expect(File.directory?(File.join(tmp_root_dir, 'crashes'))).to be(true)
      expect(File.directory?(File.join(tmp_root_dir, 'hangs'))).to be(true)
    end
  end

  context 'Saving crash tests' do
    it 'saves in crashes/' do
      store.save_report(
        classification: crash_class,
        run_result: run_result,
        minimized_input: minimized_input,
        unminimized_size: unminimized_size,
        min_result: min_result
      )

      files = Dir.glob(File.join(tmp_root_dir, 'crashes', '*.json'))
      expect(files.size).to eq(1)
    end

    it 'saves correct JSON content' do
      store.save_report(
        classification: crash_class,
        run_result: run_result,
        minimized_input: minimized_input,
        unminimized_size: unminimized_size,
        min_result: min_result
      )

      file_path = Dir.glob(File.join(tmp_root_dir, 'crashes', '*.json')).first
      data = JSON.parse(File.read(file_path), symbolize_names: true)

      # Check fields
      expect(data[:input]).to eq('A')
      expect(data[:oracle]).to eq('asan')
      expect(data[:bug_info]).to eq({ file: 'a.c', line: 10, kind: 'heap' })
      expect(data[:execution_time]).to eq(123)

      # Check minimization block
      expect(data[:minimization]).not_to be_nil
      expect(data[:minimization][:unminimized_size]).to eq(100)
      expect(data[:minimization][:nb_steps]).to eq(50)
      expect(data[:minimization][:execution_time]).to eq(2000)
    end

    it 'saves the correct JSON content without minimization' do
      store.save_report(
        classification: crash_class,
        run_result: run_result,
        minimized_input: minimized_input,
        unminimized_size: unminimized_size,
        min_result: nil # No minimization
      )

      file_path = Dir.glob(File.join(tmp_root_dir, 'crashes', '*.json')).first
      data = JSON.parse(File.read(file_path), symbolize_names: true)

      # block should be missing
      expect(data[:minimization]).to be_nil
    end
  end

  context 'Hang report tests' do
    it 'saves in hangs/' do
      store.save_report(
        classification: hang_class,
        run_result: run_result,
        minimized_input: minimized_input,
        unminimized_size: unminimized_size,
        min_result: min_result
      )

      # Check that file was created in the correct dir
      files = Dir.glob(File.join(tmp_root_dir, 'hangs', '*.json'))
      expect(files.size).to eq(1)
    end
  end
end
