# frozen_string_literal: true

require_relative '../../spec_helper'

describe Generators::CstringGenerator do
  # https://rspec.info/features/3-12/rspec-core/helper-methods/let/
  let(:seed) { 12_345 }
  let(:gen_with_seed) { described_class.new(seed: seed) }
  let(:gen2_with_seed) { described_class.new(seed: seed) }
  let(:gen_no_seed) { described_class.new }

  context 'Determinism tests' do
    it 'produces the same sequence given the same seed' do
      # We expect two generators with the same seed to be identical.
      10.times do
        expect(gen_with_seed.next.bytes).to eq(gen2_with_seed.next.bytes)
      end
    end

    it 'produces a different sequence given a different seed' do
      # We expect two generators with different seeds to diverge.
      gen_different_seed = described_class.new(seed: seed + 1)
      expect(gen_with_seed.next.bytes).not_to eq(gen_different_seed.next.bytes)
    end

    it 'produces a different sequence without a seed' do
      # Two generators without seeds should be random and different.
      expect(gen_no_seed.next.bytes).not_to eq(gen_no_seed.next.bytes)
    end
  end

  context 'Length parameter tests' do
    it 'respects min_len and max_len' do
      gen = described_class.new(min_len: 10, max_len: 20, seed: seed)
      100.times do
        len = gen.next.bytes.length
        expect(len).to be >= 10
        expect(len).to be <= 20
      end
    end

    it 'handles min_len == max_len' do
      gen = described_class.new(min_len: 5, max_len: 5, seed: seed)
      10.times do
        expect(gen.next.bytes.length).to eq(5)
      end
    end
  end

  context 'Charset parameter tests' do
    it 'uses printable ASCII by default' do
      # Default charset is (0x20..0x7E)
      input = gen_with_seed.next
      input.bytes.each_byte do |b|
        expect(b).to be >= 0x20
        expect(b).to be <= 0x7E
      end
    end

    it 'respects a custom Range charset' do
      # Only 'A' and 'B'
      gen = described_class.new(min_len: 10, max_len: 10, charset: (0x41..0x42), seed: seed)
      gen.next.bytes.each_byte do |b|
        expect([0x41, 0x42]).to include(b)
      end
    end

    it 'respects a custom Array charset' do
      # Only 1, 10, 100
      charset = [1, 10, 100]
      gen = described_class.new(min_len: 10, max_len: 10, charset: charset, seed: seed)
      gen.next.bytes.each_byte do |b|
        expect(charset).to include(b)
      end
    end

    it 'respects a custom 8-BIT ASCII String charset' do
      charset = 'abc'.b
      gen = described_class.new(min_len: 10, max_len: 10, charset: charset, seed: seed)
      gen.next.bytes.each_byte do |b|
        # 'a'.ord == 97, 'b'.ord == 98, 'c'.ord == 99
        expect([97, 98, 99]).to include(b)
      end
    end
  end

  context 'Null byte tests' do
    it 'does not include \\x00 when allow_null: false (default)' do
      # Use a charset that explicitly includes NULL
      gen = described_class.new(min_len: 10, max_len: 10, charset: (0x00..0x05), allow_null: false, seed: seed)
      gen.next.bytes.each_byte do |b|
        expect(b).not_to eq(0x00)
        expect(b).to be_between(0x01, 0x05).inclusive
      end
    end

    it 'includes \\x00 when allow_null: true' do
      # Use a charset that is *only* NULL
      gen = described_class.new(min_len: 10, max_len: 10, charset: [0x00], allow_null: true, seed: seed)
      expect(gen.next.bytes).to eq("\x00" * 10)
    end
  end

  context 'Guard tests' do
    it 'raises ArgumentError for max_len < min_len' do
      expect do
        described_class.new(min_len: 10, max_len: 9)
      end.to raise_error(ArgumentError, /max_len must be >= min_len/)
    end

    it 'raises ArgumentError for an empty charset' do
      # A charset that becomes empty after filtering nulls
      expect do
        described_class.new(charset: [0x00], allow_null: false)
      end.to raise_error(ArgumentError, %r{charset/pool cannot be empty})
    end

    it 'raises ArgumentError for an unsupported charset type' do
      expect do
        described_class.new(charset: 123)
      end.to raise_error(ArgumentError, /unsupported charset/)
    end
  end
end
