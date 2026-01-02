# frozen_string_literal: true

require_relative '../../spec_helper'
require_relative '../../../lib/greybox/seed'

RSpec.describe Greybox::Seed do
  let(:data) { 'A' * 100 } # 100 bytes
  # 50ms execution time
  subject { described_class.new(data: data, exec_time_ms: 50) }

  describe '#initialization' do
    it 'sets default stats' do
      expect(subject.energy).to eq(1.0)
      expect(subject.stats.file_len).to eq(100)
      expect(subject.stats.mutation_count).to eq(0)
      expect(subject.stats.new_coverage_count).to eq(0)
    end
  end

  describe '#performance_score' do
    it 'calculates score based on AFL formula' do
      subject.stats.mutation_count = 200
      subject.stats.new_coverage_count = 2

      # 50 * 100 * (200 / 2) = 5000 * 100 = 500,000
      expect(subject.performance_score).to eq(500_000)
    end

    it 'handles zero new_coverage_count gracefully' do
      subject.stats.mutation_count = 100
      subject.stats.new_coverage_count = 0

      # Should divide by 1 instead of 0
      # 50 * 100 * (100 / 1) = 500,000
      expect(subject.performance_score).to eq(500_000)
    end
  end
end
