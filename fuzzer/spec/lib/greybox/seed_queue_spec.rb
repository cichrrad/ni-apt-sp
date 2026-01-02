# frozen_string_literal: true

require_relative '../../spec_helper'
require_relative '../../../lib/greybox/seed_queue'
require 'tmpdir'

RSpec.describe Greybox::SeedQueue do
  let(:tmp_dir) { Dir.mktmpdir }
  after { FileUtils.remove_entry(tmp_dir) }

  subject { described_class.new(result_dir: tmp_dir, power_schedule: :simple) }

  let(:seed1) { Greybox::Seed.new(data: 'A', coverage_hash: 'abc') }
  let(:seed2) { Greybox::Seed.new(data: 'B', coverage_hash: 'def') }

  describe '#add' do
    it 'stores seed in memory and on disk' do
      subject.add(seed1)
      expect(subject.size).to eq(1)

      # Verify file creation
      # Expected filename format: id_0_abc
      files = Dir.glob(File.join(tmp_dir, 'queue', '*'))
      expect(files.size).to eq(1)
      expect(File.basename(files.first)).to start_with('id_0_abc')
      expect(File.read(files.first)).to eq('A')
    end
  end

  describe '#sample' do
    let(:tracker) { instance_double(Greybox::CoverageTracker, path_frequency: 1) }

    it 'returns nil if queue is empty' do
      expect(subject.sample(tracker)).to be_nil
    end

    it 'returns a seed when queue is populated' do
      subject.add(seed1)
      selection = subject.sample(tracker)
      expect(selection).to eq(seed1)
    end

    it 'updates energies before sampling' do
      subject.add(seed1)

      # On first add, energy is 1.0.
      # After sample, it should be updated by the power schedule.
      # For :simple (AFL), single seed gets weight 0.5/1 = 0.5

      subject.sample(tracker)
      expect(seed1.energy).to eq(0.5)
    end
  end
end
