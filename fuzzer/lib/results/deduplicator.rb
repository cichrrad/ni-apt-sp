# frozen_string_literal: true

require 'set'

module Results
  class Deduplicator
    def initialize
      # Internally, Set uses hash
      # --> O(1) membership check
      # thank god!
      # https://medium.com/@laaveniyakirubaharan/sets-vs-arrays-in-ruby-making-the-right-choice-for-efficiency-c3ab1c31950e
      @seen_signatures = Set.new
      # NOTE: -- this may very well be scrapped
      @lock = Mutex.new
    end

    def seen?(signature)
      @lock.synchronize do
        @seen_signatures.include?(signature)
      end
    end

    # true if added, false if not
    def add(signature)
      @lock.synchronize do
        !@seen_signatures.add?(signature).nil?
      end
    end

    def count
      @lock.synchronize do
        @seen_signatures.size
      end
    end
  end
end
