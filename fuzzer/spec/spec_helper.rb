# frozen_string_literal: true

require 'simplecov'

# NO REQUIRES OTHER THAN SIMPLECOV
# CAN BE ABOVE THIS
SimpleCov.start do
  # Ignores
  add_filter '/spec/'
end

# Fuzzer parts
require_relative '../lib/generators/cstring_generator'

require 'rspec'

RSpec.configure do |config|
  # previous run result dir
  # NOTE : -- Allows work with --only-failures and --next-failure
  config.example_status_persistence_file_path = '.rspec_status'
end
