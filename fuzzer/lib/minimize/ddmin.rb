# frozen_string_literal: true

module Minimizer
  # Implements the Delta Debugging (ddmin) algorithm.
  module Ddmin
    MinimizationResult = Struct.new(:minimized_input, :nb_steps, :exec_time_ms, keyword_init: true)

    # bug_observer is a lambda returning true if
    # same bug is still present with specified
    # part of the input

    # NOTE: -- we use lambda, because if we
    # find different bug, we need to report
    # it to deduplicator
    # --> bug_observer defined in the main script
    # context, where we can do that
    def self.run(input_bytes:, bug_observer:)
      raise ArgumentError, 'Input cannot be empty' if input_bytes.empty?
      raise ArgumentError, 'bug_observer is required' unless bug_observer.respond_to?(:call)

      t_start = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      nb_steps = 0

      input_array = input_bytes.bytes
      n = 2

      while n <= input_array.length
        chunks = split_into_chunks(input_array, n)
        made_progress = false

        # Is the bug still there if we remove this chunk?
        (0...chunks.length).each do |i|
          complement = chunks[0...i] + chunks[(i + 1)..-1]
          complement_bytes = complement.flatten.pack('C*')

          next if complement_bytes.empty?

          nb_steps += 1
          next unless bug_observer.call(complement_bytes)

          # Yes ==> drop this chunk
          input_array = complement.flatten
          n = [n - 1, 2].max # Reduce n, but not below 2
          made_progress = true
          break
        end
        next if made_progress # Restart loop with smaller input

        # Is the bug only in this one chunk?
        # (This only runs if complement loop above
        # failed to make progress)
        chunks.each do |chunk|
          nb_steps += 1
          next unless bug_observer.call(chunk.pack('C*'))

          # Yes ==> The bug is only in this chunk
          input_array = chunk
          n = 2 # Restart with the smaller input
          made_progress = true
          break
        end
        next if made_progress # Restart loop with smaller input

        # no progress with n chunks ==> try n+1.
        break if n >= input_array.length # We've already tried at max granularity

        # Double the granularity, but cap it at the input length
        n = [n * 2, input_array.length].min

      end # while

      t_end = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      exec_time_ms = ((t_end - t_start) * 1000.0).to_i

      MinimizationResult.new(
        minimized_input: input_array.pack('C*').force_encoding('ASCII-8BIT'),
        nb_steps: nb_steps,
        exec_time_ms: exec_time_ms
      )
    end

    # Split byte array into n chunks (somewhat) evenly
    def self.split_into_chunks(array, n)
      return [] if n.zero?
      return array.map { |x| [x] } if n >= array.length

      base_size = array.length / n
      remainder = array.length % n

      chunks = []
      start = 0
      n.times do |i|
        size = base_size + (i < remainder ? 1 : 0)
        chunks << array.slice(start, size)
        start += size
      end
      chunks
    end
  end
end
