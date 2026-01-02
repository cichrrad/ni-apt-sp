# frozen_string_literal: true

require_relative '../../spec_helper'
require_relative '../../../lib/greybox/coverage_tracker'

RSpec.describe Greybox::CoverageTracker do
  subject { described_class.new }

  describe 'interesting?' do
    it 'returns false for empty coverage data' do
      expect(subject.interesting?(nil)).to be false
      expect(subject.interesting?([])).to be false
    end

    it 'identifies new coverage as interesting' do
      # Hit lines 1, 2, 3
      is_interesting, hash = subject.interesting?([0, 1, 1, 1])

      expect(is_interesting).to be true
      expect(hash).not_to be_nil
      expect(subject.global_hits).to include(1, 2, 3)
    end

    it 'returns false for repeated coverage (subset of known)' do
      # Initial run: lines 1, 2
      subject.interesting?([0, 1, 1, 0])

      # Second run: same lines
      is_interesting, = subject.interesting?([0, 1, 1, 0])
      expect(is_interesting).to be false
    end

    it 'tracks path frequencies consistently' do
      # Run 1
      _, hash1 = subject.interesting?([0, 1, 0])
      # Run 2 (Same path)
      _, hash2 = subject.interesting?([0, 1, 0])

      expect(hash1).to eq(hash2)
      expect(subject.path_frequency(hash1)).to eq(2)
    end
  end
end
