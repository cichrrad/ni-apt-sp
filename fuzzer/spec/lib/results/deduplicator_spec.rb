# frozen_string_literal: true

require_relative '../../spec_helper'
require_relative '../../../lib/results/deduplicator'

describe Results::Deduplicator do
  let(:dedup) { described_class.new }
  let(:sig_a) { 'asan:heap:main.c:10' }
  let(:sig_b) { 'rc:139' }

  context 'Empty tests' do
    it 'Reports empty' do
      expect(dedup.count).to eq(0)
    end

    it 'Reports #seen? as false' do
      expect(dedup.seen?(sig_a)).to be(false)
    end
  end

  context '1 signature tests' do
    before { dedup.add(sig_a) }

    it 'Reports count as 1' do
      expect(dedup.count).to eq(1)
    end

    it 'Reports #seen? as true for correct' do
      expect(dedup.seen?(sig_a)).to be(true)
    end

    it 'Reports #seen? as false for different' do
      expect(dedup.seen?(sig_b)).to be(false)
    end
  end

  context 'Add method tests' do
    it 'Returns true when adding' do
      return_val = dedup.add(sig_a)
      expect(return_val).to be(true)
    end

    it 'Returns false when adding duplicate' do
      dedup.add(sig_a)
      return_val = dedup.add(sig_a)
      expect(return_val).to be(false)
    end

    it 'Returns true for new' do
      dedup.add(sig_a)
      return_val = dedup.add(sig_b)
      expect(return_val).to be(true)
      expect(dedup.count).to eq(2)
    end
  end
end
