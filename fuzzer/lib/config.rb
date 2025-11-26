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

  # Start up guards
  def self.validate!
    raise 'ERROR: FUZZED_PROG env var not set or empty.' if FUZZED_PROG.nil? || FUZZED_PROG.empty?
    raise "ERROR: FUZZED_PROG '#{FUZZED_PROG}' not found or not executable." unless File.executable?(FUZZED_PROG)
    raise 'ERROR: RESULT_FUZZ env var not set or empty.' if RESULT_FUZZ.nil? || RESULT_FUZZ.empty?

    # Try to crete result dir
    begin
      FileUtils.mkdir_p(RESULT_FUZZ)
    rescue SystemCallError => e
      raise "ERROR: Could not create result directory '#{RESULT_FUZZ}': #{e.message}"
    end
  end
end
