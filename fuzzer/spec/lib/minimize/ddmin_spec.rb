# frozen_string_literal: true

require_relative '../../spec_helper'
require_relative '../../../lib/minimize/ddmin'
require_relative '../../../lib/results/deduplicator'

# NOTE: -- To be able to check all the scenarios
# we want, we will use specialized bug_observer
# lambdas (in the whole program, this lambda
# will work on classification results
# from oracles. Here it is used to target
# chars / combinations of chars to test
# minimization and bug reporting )

describe Minimizer::Ddmin do
  def minimize(input, bug_observer)
    res = described_class.run(
      input_bytes: input.b,
      bug_observer: bug_observer
    )
    res.minimized_input
  end

  context 'Basic bug str tests' do
    it 'Minimize into single char' do
      input = 'prefix_!_suffix'
      bug_observer = ->(bytes) { bytes.include?('!'.b) }
      expect(minimize(input, bug_observer)).to eq('!'.b)
    end

    it 'Minimize into substring' do
      input = 'prefix_BAD_BUG_suffix'
      bug_observer = ->(bytes) { bytes.include?('BAD_BUG'.b) }
      expect(minimize(input, bug_observer)).to eq('BAD_BUG'.b)
    end

    it 'Minimize along complement path' do
      input = 'A_plus_B_equals_C'
      bug_observer = ->(bytes) { bytes.include?('A'.b) && bytes.include?('C'.b) }

      minimized = minimize(input, bug_observer)

      # order agnostic in this case
      expect(minimized.length).to eq(2)
      expect(minimized).to include('A'.b)
      expect(minimized).to include('C'.b)
    end

    it 'Head bug' do
      input = 'BUG_suffix'
      bug_observer = ->(bytes) { bytes.include?('BUG'.b) }
      expect(minimize(input, bug_observer)).to eq('BUG'.b)
    end

    it 'Tail bug' do
      input = 'prefix_BUG'
      bug_observer = ->(bytes) { bytes.include?('BUG'.b) }
      expect(minimize(input, bug_observer)).to eq('BUG'.b)
    end
  end

  context 'New bugs found tests' do
    let(:deduplicator) { instance_double(Results::Deduplicator) }
    let(:minimization_queue) { [] }
    let(:original_sig) { 'bug:A'.b }
    let(:new_sig) { 'bug:B'.b }

    # this lambda works
    # with deduplicator
    # and pushes new bugs
    let(:smart_bug_observer) do
      lambda do |bytes|
        # og bug
        if bytes.include?('A'.b)
          true
        elsif bytes.include?('B'.b)
          # different bug
          # check if it's new and add it
          minimization_queue.push(new_sig) if deduplicator.add(new_sig)
          false # not the original bug
        else
          # found no bug
          false
        end
      end
    end

    it 'Minimizes og bug AND reports new' do
      input = '...A...B...'

      # ORDER HERE MATTERS
      # (this must be above .run)
      # Expect add("bug:B") to be called, and return true (it's new)
      expect(deduplicator).to receive(:add).with(new_sig).and_return(true)

      result = described_class.run(
        input_bytes: input.b,
        bug_observer: smart_bug_observer
      )

      expect(result.minimized_input).to eq('A'.b)

      expect(minimization_queue).to eq([new_sig])
    end

    it 'Minimizes og bug AND reports new (already added)' do
      # Expect add("bug:B") to be called, and return false (it's known)
      expect(deduplicator).to receive(:add).with(new_sig).and_return(false)

      input = '...A...B...'
      result = described_class.run(
        input_bytes: input.b,
        bug_observer: smart_bug_observer
      )

      expect(result.minimized_input).to eq('A'.b)

      expect(minimization_queue).to be_empty
    end
  end
end
