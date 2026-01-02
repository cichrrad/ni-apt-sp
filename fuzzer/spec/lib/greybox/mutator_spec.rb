require_relative '../../spec_helper'
require_relative '../../../lib/greybox/mutator'

RSpec.describe Greybox::Mutator do
  let(:rng) { instance_double(Random) }
  subject { described_class.new(rng: rng) }
  let(:data) { 'ABCD'.b }

  describe 'mutate' do
    context 'BitFlip' do
      it 'flips a specific bit' do
        # 1. nb_mutations (1..4) -> 1
        # 2. op (5) -> 0 (BitFlip)
        # 3. byte_idx (4) -> 0
        # 4. bit_idx (8) -> 0
        expect(rng).to receive(:rand).with(1..4).and_return(1)
        expect(rng).to receive(:rand).with(5).and_return(0)
        expect(rng).to receive(:rand).with(4).and_return(0)
        expect(rng).to receive(:rand).with(8).and_return(0)

        # 'A' is 0x41 (0100 0001). Flip bit 0 -> 0x40 (0100 0000) -> '@'
        result = subject.mutate(data)
        expect(result).to eq('@BCD'.b)
      end
    end

    context 'Arithmetic' do
      it 'adds small integer to a byte' do
        # nb_mutations (1..4) -> 1
        expect(rng).to receive(:rand).with(1..4).and_return(1)

        # op (5) -> 1 (Arithmetic)
        expect(rng).to receive(:rand).with(5).and_return(1)

        # byte_idx (4) -> 0
        expect(rng).to receive(:rand).with(4).and_return(0)

        # biased_value prob check: rand() -> 0.9 (> 0.8, so it continues)
        expect(rng).to receive(:rand).with(no_args).and_return(0.9)

        # biased_value val: rand(1..35) -> 5
        expect(rng).to receive(:rand).with(1..35).and_return(5)

        # sign: rand(2) -> 0 (Add)
        expect(rng).to receive(:rand).with(2).and_return(0)

        # 'A' (65) + 5 = 'F' (70)
        result = subject.mutate(data)
        expect(result).to eq('FBCD'.b)
      end
    end

    context 'Block Delete' do
      it 'removes a slice of data' do
        # nb_mutations (1..4) -> 1
        expect(rng).to receive(:rand).with(1..4).and_return(1)

        # op (5) -> 2 (Delete)
        expect(rng).to receive(:rand).with(5).and_return(2)

        # biased_value prob: rand() -> 0.9
        expect(rng).to receive(:rand).with(no_args).and_return(0.9)

        # biased_value val: rand(1..4) -> 2 (Len)
        expect(rng).to receive(:rand).with(1..4).and_return(2)

        # start index: rand(3) -> 1
        # Calculation: size 4 - len 2 + 1 = 3
        expect(rng).to receive(:rand).with(3).and_return(1)

        # "A[BC]D" delete 2 at index 1 -> "AD"
        result = subject.mutate(data)
        expect(result).to eq('AD'.b)
      end
    end
  end
end
