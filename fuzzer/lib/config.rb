# frozen_string_literal: true

require 'fileutils'

# ENV var capture & sanity checks before run
module Config
  FUZZED_PROG = ENV.fetch('FUZZED_PROG')
  RESULT_FUZZ = ENV.fetch('RESULT_FUZZ')
  FUZZER_NAME = 'fuzzy_wuzzy_39901'
  INPUT_MODE = case ENV['INPUT']&.downcase
               when 'file'
                 :file
               else
                 :stdin # default for runner
               end

  # Yucky as we default to enabled if missing
  MINIMIZE_DISABLED = (ENV['MINIMIZE'] == '0')
  MINIMIZE_ENABLED = !MINIMIZE_DISABLED

  TIMEOUT = ENV['TIMEOUT']

  # Power Schedule: :simple (default), :boosted, :fast
  POWER_SCHEDULE = case ENV['POWER_SCHEDULE']&.downcase
                   when 'boosted' then :boosted
                   when 'fast'    then :fast
                   else :simple
                   end

  INPUT_SEEDS = ENV['INPUT_SEEDS']

  # Fuzzer Type: :greybox (default), :blackbox
  FUZZER_TYPE = case ENV['FUZZER']&.downcase
                when 'blackbox' then :blackbox
                else :greybox
                end

  # 'Global' getters for env vars
  def self.fuzzed_program
    FUZZED_PROG
  end

  def self.timeout
    TIMEOUT
  end

  def self.result_dir
    RESULT_FUZZ
  end

  def self.fuzzer_name
    FUZZER_NAME
  end

  def self.input_mode
    INPUT_MODE
  end

  def self.minimize_enabled?
    MINIMIZE_ENABLED
  end

  def self.power_schedule
    POWER_SCHEDULE
  end

  def self.input_seeds
    INPUT_SEEDS
  end

  def self.fuzzer_type
    FUZZER_TYPE
  end

  # Start up guards
  def self.validate!
    raise 'ERROR: FUZZED_PROG env var not set or empty.' if FUZZED_PROG.nil? || FUZZED_PROG.empty?

    # Check if file or directory exists
    raise "ERROR: FUZZED_PROG '#{FUZZED_PROG}' not found." unless File.exist?(FUZZED_PROG)

    # If it is a file, it must be executable (Blackbox mode compatibility)
    if File.file?(FUZZED_PROG) && !File.executable?(FUZZED_PROG)
      raise "ERROR: FUZZED_PROG '#{FUZZED_PROG}' found but not executable."
    end

    raise 'ERROR: RESULT_FUZZ env var not set or empty.' if RESULT_FUZZ.nil? || RESULT_FUZZ.empty?

    # Try to crete result dir
    begin
      FileUtils.mkdir_p(RESULT_FUZZ)
    rescue SystemCallError => e
      raise "ERROR: Could not create result directory '#{RESULT_FUZZ}': #{e.message}"
    end
  end
end
