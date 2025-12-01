# frozen_string_literal: true

require 'set'
require 'digest'

module Greybox
  class CoverageTracker
    attr_reader :global_hits, :path_frequencies

    def initialize
      @global_hits = Set.new
      @path_frequencies = Hash.new(0)
    end

    def interesting?(raw_coverage_data)
      return false if raw_coverage_data.nil? || raw_coverage_data.empty?

      hit_ids = []
      is_interesting = false
      # Build ID List AND Check Global Coverage
      raw_coverage_data.each_with_index do |count, idx|
        next unless count.positive?

        # found a hit
        hit_ids << idx
        # Check if this line ID is new
        # .add? returns the object if added (truthy), or nil if already present
        is_interesting = true if @global_hits.add?(idx)
      end

      # if no lines were hit (empty run) not interesting
      return false if hit_ids.empty?

      # update path frequency
      path_hash = Digest::SHA256.hexdigest(hit_ids.join(','))
      @path_frequencies[path_hash] += 1

      [is_interesting, path_hash]
    end

    def path_frequency(path_hash)
      @path_frequencies[path_hash]
    end
  end
end
