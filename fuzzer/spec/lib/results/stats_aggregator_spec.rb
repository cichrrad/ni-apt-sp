# frozen_string_literal: true

require_relative '../../spec_helper'
require 'json'
require 'tempfile'
# For fake results
require_relative '../../../lib/runner/external_runner'
require_relative '../../../lib/oracle/chain'
require_relative '../../../lib/minimize/ddmin'

require_relative '../../../lib/results/stats_aggregator'

describe Results::StatsAggregator do
  let(:fuzzer_name) { 'test_fuzzer' }
  let(:fuzzed_program) { '/bin/test' }
  let(:aggregator) { described_class.new(fuzzer_name: fuzzer_name, fuzzed_program: fuzzed_program) }

  # Fake RunResults and classifications
  let(:pass_result) { RunResult.new(wall_time_ms: 10) }
  let(:pass_class) { Classification.new(status: :pass) }

  let(:fail_result) { RunResult.new(wall_time_ms: 20) }
  let(:fail_class) { Classification.new(status: :fail) }

  let(:hang_result) { RunResult.new(wall_time_ms: 30) }
  let(:hang_class) { Classification.new(status: :hang) }

  let(:min_result) { Minimizer::Ddmin::MinimizationResult.new(nb_steps: 100, exec_time_ms: 500) }
  let(:min_result_2) { Minimizer::Ddmin::MinimizationResult.new(nb_steps: 200, exec_time_ms: 1500) }

  context 'Init tests' do
    it 'writes out default stats' do
      Tempfile.create('stats.json') do |f|
        aggregator.save(f.path)
        data = JSON.parse(File.read(f.path), symbolize_names: true)

        expect(data[:fuzzer_name]).to eq(fuzzer_name)
        expect(data[:fuzzed_program]).to eq(fuzzed_program)
        expect(data[:nb_runs]).to eq(0)
        expect(data[:nb_failed_runs]).to eq(0)
        expect(data[:nb_hanged_runs]).to eq(0)
        expect(data[:nb_unique_failures]).to eq(0)
        expect(data[:minimization][:before]).to eq(0)
      end
    end

    it 'handles empty timing array' do
      # bad practice
      timings = aggregator.send(:calculate_timings, [])
      expect(timings).to eq({ average: 0, median: 0, min: 0, max: 0 })
    end
  end

  context 'With data tests' do
    before do
      # Simulate runs
      aggregator.record_run(pass_result, pass_class)
      aggregator.record_run(fail_result, fail_class)
      aggregator.record_run(hang_result, hang_class)

      # new bugs for fail and hang
      aggregator.record_new_discovery
      aggregator.record_new_discovery

      # minimized fail and hang bus
      aggregator.record_minimization(min_result)
      aggregator.record_minimization(min_result_2)

      aggregator.record_saved_report
    end

    it 'counts run correctly' do
      # bad practice
      data = JSON.parse(aggregator.send(:build_report).to_json, symbolize_names: true)
      expect(data[:nb_runs]).to eq(3)
      expect(data[:nb_failed_runs]).to eq(1)
      expect(data[:nb_hanged_runs]).to eq(1)
    end

    it 'counts fails correctly' do
      # bad practice
      data = JSON.parse(aggregator.send(:build_report).to_json, symbolize_names: true)
      expect(data[:nb_unique_failures]).to eq(1) # From record_saved_report
      expect(data[:minimization][:before]).to eq(2) # From record_new_discovery
    end

    it 'calculates timing stats correctly' do
      # bad practice
      data = JSON.parse(aggregator.send(:build_report).to_json, symbolize_names: true)
      stats = data[:execution_time]
      # timings = [10, 20, 30]
      expect(stats[:average]).to eq(20.0)
      expect(stats[:median]).to eq(20.0)
      expect(stats[:min]).to eq(10)
      expect(stats[:max]).to eq(30)
    end

    it 'calculates minimization stats correctly' do
      # bad practice
      data = JSON.parse(aggregator.send(:build_report).to_json, symbolize_names: true)
      stats = data[:minimization]
      # steps = [100, 200], times = [500, 1500]
      expect(stats[:avg_steps]).to eq(150.0)
      expect(stats[:execution_time][:average]).to eq(1000.0)
      expect(stats[:execution_time][:median]).to eq(1000.0)
      expect(stats[:execution_time][:min]).to eq(500)
      expect(stats[:execution_time][:max]).to eq(1500)
    end
  end

  context 'Median tests' do
    it 'calculates odd array' do
      # sorts to [10, 20, 50]
      median = aggregator.send(:median, [10, 50, 20])
      expect(median).to eq(20.0)
    end

    it 'calculates for even array' do
      # sorts to [10, 20, 30, 40]
      median = aggregator.send(:median, [30, 10, 40, 20])
      # (20 + 30) / 2
      expect(median).to eq(25.0)
    end
  end
end
