# frozen_string_literal: true

require 'fileutils'
require_relative 'seed'

module Greybox
  class SeedQueue
    attr_reader :queue

    def initialize(result_dir:, power_schedule: :simple)
      @result_dir = result_dir
      @power_schedule = power_schedule # :simple, :boosted, :fast

      @queue_dir = File.join(result_dir, 'queue')
      FileUtils.mkdir_p(@queue_dir)

      @queue = []
      @rng = Random.new
    end

    def empty?
      @queue.empty?
    end

    def size
      @queue.size
    end

    def add(seed)
      # save to disk
      filename = "id_#{@queue.size}_#{seed.coverage_hash[0, 8]}"
      path = File.join(@queue_dir, filename)

      # only write if data present (safety)
      File.binwrite(path, seed.data) if seed.data

      # Add to memory
      @queue << seed
    end

    # MUTATOR
    # For Splicing: Just grab a random partner
    def sample_random
      return nil if @queue.empty?

      @queue.sample(random: @rng)
    end

    # MAIN LOOP
    # Returns a Seed based on weighted random choice (Power Schedule)
    def sample(coverage_tracker)
      return nil if @queue.empty?

      # Recalculate weights before sampling
      update_energies(coverage_tracker)

      # Weighted random selection
      total_energy = @queue.sum(&:energy)
      target = @rng.rand * total_energy

      cumulative = 0.0
      @queue.each do |seed|
        cumulative += seed.energy
        return seed if cumulative >= target
      end

      @queue.last
    end

    private

    def update_energies(tracker)
      case @power_schedule
      when :boosted
        update_boosted(tracker)
      when :fast
        update_fast(tracker)
      else # :simple / :afl
        update_afl
      end
    end

    # AFL-inspired:
    # Rank by score T * l * (nm/nc). Best 10% get 50% of weight.
    def update_afl
      return if @queue.empty?

      # Sort by performance (lower is better)
      sorted = @queue.sort_by(&:performance_score)

      top_count = (sorted.size * 0.1).ceil
      top_seeds = sorted.first(top_count)
      other_seeds = sorted.drop(top_count)

      # Assign weights
      top_weight = 0.5 / top_count
      other_weight = other_seeds.empty? ? 0 : (0.5 / other_seeds.size)

      top_seeds.each { |s| s.energy = top_weight }
      other_seeds.each { |s| s.energy = other_weight }
    end

    # Boosted: e = 1 / f(p)^5
    def update_boosted(tracker)
      @queue.each do |s|
        freq = tracker.path_frequency(s.coverage_hash)
        freq = 1 if freq < 1
        s.energy = 1.0 / (freq**5)
      end
    end

    # Fast: 1/M * min( ... )
    def update_fast(tracker)
      beta = 1.0 # Tunable
      m_const = 32.0 # Upper bound (M)

      update_afl # Calculate alpha(s) first (stored in current s.energy)

      @queue.each do |s|
        alpha = s.energy # reusing AFL weight as alpha
        freq = tracker.path_frequency(s.coverage_hash)
        freq = 1 if freq < 1

        # 2^(n(s)) -> mutation count
        numerator = alpha * (2**s.stats.mutation_count)
        term = numerator / (beta * freq)

        # min(term, M)
        val = [term, m_const].min

        s.energy = val / m_const
      end
    end
  end
end
