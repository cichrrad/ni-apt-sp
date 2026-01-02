# frozen_string_literal: true

module Greybox
  class Mutator
    def initialize(rng: Random.new)
      @rng = rng
    end

    def mutate(seed_data, corpus = nil)
      # work on bytes
      data = seed_data.b.dup

      # apply 1 to 4 mutations
      nb_mutations = @rng.rand(1..4)

      nb_mutations.times do
        # Pick operator
        # 0: BitFlip
        # 1: Arith
        # 2: Delete
        # 3: Insert
        # 4: Splice
        op = @rng.rand(5)

        case op
        when 0 then bit_flip(data)
        when 1 then arithmetic(data)
        when 2 then block_delete(data)
        when 3 then block_insert(data)
        when 4 then splice(data, corpus)
        end
      end

      data
    end

    private

    # Mutation ops
    def bit_flip(data)
      return if data.empty?

      # pick random byte and bit
      byte_idx = @rng.rand(data.bytesize)
      bit_idx = @rng.rand(8)

      # flip it
      byte = data.getbyte(byte_idx)
      new_byte = byte ^ (1 << bit_idx)
      data.setbyte(byte_idx, new_byte)
    end

    def arithmetic(data)
      return if data.empty?

      byte_idx = @rng.rand(data.bytesize)
      val = biased_value(35) # 80/20 to pick 1 or in range 1..35

      # 50/50 +/-
      new_byte = if @rng.rand(2).zero?
                   (data.getbyte(byte_idx) + val) & 0xFF
                 else
                   (data.getbyte(byte_idx) - val) & 0xFF
                 end
      data.setbyte(byte_idx, new_byte)
    end

    def block_delete(data)
      return if data.empty?

      # 80/20 to pick 1 or in range 1..data.bytesize
      len = biased_value(data.bytesize)
      start = @rng.rand(data.bytesize - len + 1) # ensure it fits

      # slice out
      data.slice!(start, len)
    end

    def block_insert(data)
      # 80/20 -||-
      len = biased_value(64)

      # generate random block
      block = String.new(capacity: len)
      len.times { block << @rng.rand(256) }

      # random insert spot (can append too)
      pos = @rng.rand(data.bytesize + 1)
      data.insert(pos, block)
    end

    # select another seed from Q
    # slice and hack together
    # new offspring
    def splice(data, corpus)
      return unless corpus && !corpus.empty?

      # Pick random other
      other = corpus.sample_random
      other_data = other.data
      return if other_data.empty? || data.empty?

      # pick random split points
      split_a = @rng.rand(data.bytesize)
      split_b = @rng.rand(other_data.bytesize)

      # Frankenstein together
      new_data = data.byteslice(0, split_a) + other_data.byteslice(split_b, other_data.bytesize)

      # replace current buffer with spliced one
      data.replace(new_data)
    end

    # Returns 1 with 80% prob, else 1..max
    def biased_value(max_val)
      return 1 if max_val <= 1
      return 1 if @rng.rand < 0.8

      @rng.rand(1..max_val)
    end
  end
end
