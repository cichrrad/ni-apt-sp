# frozen_string_literal: true

module Greybox
  class Seed
    attr_reader :data, :filename, :coverage_hash
    attr_accessor :energy, :stats

    # stats/performance metadata
    Stats = Struct.new(
      :exec_time_ms,
      :mutation_count,      # n_m
      :new_coverage_count,  # n_c
      :file_len,
      :path_frequency,      # f(p)
      keyword_init: true
    )

    def initialize(data:, filename: nil, coverage_hash: nil, exec_time_ms: 0)
      @data = data
      @filename = filename
      @coverage_hash = coverage_hash
      @energy = 1.0 # Default weight

      @stats = Stats.new(
        exec_time_ms: exec_time_ms,
        mutation_count: 0,
        new_coverage_count: 0,
        file_len: data.bytesize,
        path_frequency: 1
      )
    end

    # AFL power schedule
    # smaller is better
    def performance_score
      # Avoid division by zero
      nc = @stats.new_coverage_count.positive? ? @stats.new_coverage_count : 1

      # T * l * (nm / nc)
      @stats.exec_time_ms * @stats.file_len * (@stats.mutation_count.to_f / nc)
    end
  end
end
