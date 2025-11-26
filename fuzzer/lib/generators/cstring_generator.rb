# frozen_string_literal: true

# return type
FuzzInput = Struct.new(:bytes, :generator_id, :seed, :iteration, keyword_init: true)

module Generators
  # CstringGenerator produces raw BYTES (ASCII-8BIT) with NO embedded NULs by default.
  # Determinism:
  #   - Pass a specific `seed:` OR a `rng:` (Random instance) to make the sequence reproducible.
  #
  # Charset:
  #   - Default is printable ASCII (0x20..0x7E).
  #   - Can provide `charset:` as:
  #       * a Range of bytes (e.g., 0x20..0x7E),
  #       * an Array containing Ranges/Integers/Strings,
  #       * a String of allowed bytes (ASCII-8BIT),
  #       => all morphed into pool to pull from
  #   - `allow_null:` (default false) allows 0x00; (for C OFF)
  #
  # Length:
  #   - Picked uniformly in [min_len, max_len].
  class CstringGenerator
    DEFAULT_CHARSET = (0x20..0x7E).freeze # printable ASCII
    attr_reader :min_len, :max_len, :id, :seed

    def initialize(min_len: 0, max_len: 64, charset: DEFAULT_CHARSET, allow_null: false, id: 'cstring', rng: nil,
                   seed: nil)
      raise ArgumentError, 'min_len must be >= 0' if min_len.negative?
      raise ArgumentError, 'max_len must be >= min_len' if max_len < min_len

      # TEMP HOTFIX
      # @curr = 0
      # @inputs = [
      #   '1002VlXxTIMsGHFRdJalmCYvgnW0RcMQtpq1XF5NCx2bEfjbWveKR3HkqzzWnMg4DVb2htKJVx55cfjiydvhFtISvPifaIKnxwBJiFqpQBvacwbpeL7YegUDAKhgk6gDnKj8qayGxiCqD7Re8WhVpC2siELzrrNJFNqDExGENljFMoNPA409lKVQDGAq0XqneFtL82cdK99RrX7vQ9vUBaFAb1TwTUCzqcKkuuX73dIGeiXXwAiDTrTXwWeCs2Fww8rWLduWIp5x372eid33GpjJuyGQz2eH0ebYUAvK2Hdzsy11MfDYo1ygdOxhHrbBZ9zrJr7xQIBojB80dRcpsvz7oZj6ItkP11s5p7Iaiwdxsp2hUdJ00p28q3Vu1KCQzzsTOV3qYUsHBWjXEvTYH1JvlkMRatpYXjeVOPNusF8LRTGbsBuMW6IpUv9iW5nz8B9ggZ6pOwNR3tLOmWiaUlotoWjNfz63AOg8AgaEPG04fZ3zWD5XBHHpIMV021eJMktzHXMF8uqUKkJ4UVchNEITRi2IjUoFYN7kedkZUnBfkbogJf2bqkUSA0Sy2Nzm6mse2dheU7OuanVykteQWCdx45qNEI0txItdnqOlWmhOSU5yxQFNt7V67XZmHNGkVv6kEK5b82rQ4jyzNKDUHE31zOOFMUQ0c3MEvJjZE8uQCeEXSD7DoKH1teXzcuAA5FgvMwSxCJSalhwFcDrhWyDr87ct2MD9ZExf95ZOFGEjrEC04nfDan0AO9k7KVizolTUuGoeP6qqf7l1QLzqtX22Zy4bj924jwMcrMALqvmMgUgp98O17hIsRfSVizjM5V2KcBsdb31glhCzZ1nckZ1LD4J6jFjBVzuE8HA3XF5fNRl7PXlDgjcm8J1GakYTJh6Ed7ZF5DBltLf39DqxBAzSstGTDX37EmnvSN9wtYYOrudSGoaaLa5rK7Sh67CGWn4k4NHxM6k1CSDSmGG4u5av1ke7fMYiiBDFST9x', '()', '345701', '1002Interesting Pattern', '123Interesting Pattern', '1002VlXxTIMsGHFRdJalmcCYvgnW0RcMQtpq1XF5NCx2bEfjbWveKR3HkqzzWnMg4DVb2htKJVx55cfjiydvhFtISvPifaIKnxwBJiFqpQBvacwbpeL7YegUDAKhgk6gDnKj8qayGxiCqD7Re8WhVpC2siELzrrNJFNqDExGENljFMoNPA409lKVQDGAq0XqneFtL82cdK99RrX7vQ9vUBaFAb1TwTUCzqcKkuuX73dIGeiXXwAiDTrTXwWeCs2Fww8rWLduWIp5x372eid33GpjJuyGQz2eH0ebYUAvK2Hdzsy11MfDYo1ygdOxhHrbBZ9zrJr7xQIBojB80dRcpsvz7oZj6ItkP11s5p7Iaiwdxsp2hUdJ00p28q3Vu1KCQzzsTOV3qYUsHBWjXEvTYH1JvlkMRatpYXjeVOPNusF8LRTGbsBuMW6IpUv9iW5nz8B9ggZ6pOwNR3tLOmWiaUlotoWjNfz63AOg8AgaEPG04fZ3zWD5XBHHpIMV021eJMktzHXMF8uqUKkJ4UVchNEITRi2IjUoFYN7kedkZUnBfkbogJf2bqkUSA0Sy2Nzm6mse2dheU7OuanVykteQWCdx45qNEI0txItdnqOlWmhOSU5yxQFNt7V67XZmHNGkVv6kEK5b82rQ4jyzNKDUHE31zOOFMUQ0c3MEvJjZE8uQCeEXSD7DoKH1teXzcuAA5FgvMwSxCJSalhwFcDrhWyDr87ct2MD9ZExf95ZOFGEjrEC04nfDan0AO9k7KVizolTUuGoeP6qqf7l1QLzqtX22Zy4bj924jwMcrMALqvmMgUgp98O17hIsRfSVizjM5V2KcBsdb31glhCzZ1nckZ1LD4J6jFjBVzuE8HA3XF5fNRl7PXlDgjcm8J1GakYTJh6Ed7ZF5DBltLf39DqxBAzSstGTDX37EmnvSN9wtYYOrudSGoaaLa5rK7Sh67CGWn4k4NHxM6k1CSDSmGG4u5av1ke7fMYiiBDFST9xbAIrS'
      # ]

      @min_len = Integer(min_len)
      @max_len = Integer(max_len)
      @id      = String(id)
      @seed    = seed || rng&.seed || Random.new_seed
      @rng     = rng || Random.new(@seed)

      pool = build_pool(charset)
      pool = filter_null(pool) unless allow_null
      raise ArgumentError, 'charset/pool cannot be empty' if pool.empty?

      # Better safe than sorry ?
      # https://docs.ruby-lang.org/en/3.3/String.html#method-i-force_encoding
      @pool = pool.dup.force_encoding(Encoding::ASCII_8BIT).freeze

      @iteration = 0
    end

    # Generate next input
    def next
      # TODO: -- branching should
      # probably be outside of the hot
      # path
      len = if @min_len == @max_len
              @min_len
            else
              @rng.rand(@min_len..@max_len)
            end

      # generate bytes
      bytes = String.new(capacity: len, encoding: Encoding::ASCII_8BIT)
      pool_size = @pool.bytesize
      len.times do
        idx = @rng.rand(pool_size)
        bytes << @pool.getbyte(idx)
      end

      @iteration += 1
      # new input for runner to pipe into the program
      # TEMP HOTFIX TO GET STRINGS EXPECTED BY RUNNER
      # str = @inputs[@curr]
      # @curr = @curr == @inputs.size - 1 ? 0 : @curr + 1
      # FuzzInput.new(bytes: str.b, generator_id: @id, seed: @seed, iteration: @iteration)
      FuzzInput.new(bytes: bytes, generator_id: @id, seed: @seed, iteration: @iteration)
    end

    private

    # process input charset
    def build_pool(charset)
      case charset
      # very pretty input handling
      when Range
        bytes_from_range(charset)
      when Array
        arr = []
        charset.each do |elem|
          case elem
          when Range   then arr.concat(bytes_from_range(elem))
          when Integer then arr << (elem & 0xFF)
          when String  then elem.each_byte { |b| arr << b }
          else raise ArgumentError, "unsupported charset element: #{elem.inspect}"
          end
        end
        # morph array into ASCII-8BIT
        # https://docs.ruby-lang.org/en/3.3/packed_data_rdoc.html
        arr.uniq.pack('C*')
      when String
        charset.dup.force_encoding(Encoding::ASCII_8BIT)
      when nil
        bytes_from_range(DEFAULT_CHARSET)
      # what did you enter???
      else
        raise ArgumentError, "unsupported charset: #{charset.inspect}"
      end
    end

    def bytes_from_range(r)
      from = Integer(r.begin) & 0xFF
      to   = Integer(r.end) & 0xFF
      to  -= 1 if r.exclude_end?
      raise ArgumentError, 'empty range' if to < from

      (from..to).to_a.pack('C*')
    end

    def filter_null(pool_bytes)
      return pool_bytes unless pool_bytes.include?("\x00")

      # Remove 0x00 from the pool
      filtered = pool_bytes.bytes.reject { |b| b.zero? }
      filtered.pack('C*')
    end
  end
end
