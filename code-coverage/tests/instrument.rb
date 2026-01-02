#!/usr/bin/env ruby
# frozen_string_literal: true

require 'fileutils'
require 'pathname'
require 'tree_stand'

if ENV['COVERAGE'] == 'true'
  require 'simplecov'

  project_root = File.expand_path('..', __dir__) # one level up from instrument.rb
  SimpleCov.root project_root
  SimpleCov.coverage_dir File.join(project_root, 'coverage')
  SimpleCov.merge_timeout 86_400 
  SimpleCov.command_name(ENV['COVERAGE_NAME'] || "instrument-#{Process.pid}")

  SimpleCov.start do
    enable_coverage :branch
    track_files File.join(project_root, 'src/**/*.rb')   # track all src files
    add_filter File.join(project_root, 'instrument.rb')  # exclude the CLI itself
    add_filter %r{/test/|/spec/|/vendor/}
  end
end

# Ensure ../src is on the load path regardless of current working dir
$LOAD_PATH.unshift File.expand_path(File.join('..', 'src'), __dir__)

require_relative '../src/FileModel'
require_relative '../src/Analyzer'
require_relative '../src/Instrumentor'

USAGE = <<~TXT
  Usage:
    #{File.basename($0)} [SOURCE_DIR] [OUT_DIR]

  Defaults:
    SOURCE_DIR = ENV['TARGET_COV'] or '.'
    OUT_DIR    = 'build_cov'

  Example:
    TARGET_COV=examples #{File.basename($0)}
TXT

source_dir = ARGV[0] || ENV['TARGET_COV'] || '.'
out_dir    = ARGV[1] || 'build_cov'

unless Dir.exist?(source_dir)
  warn "Source dir not found: #{source_dir}\n\n#{USAGE}"
  exit 1
end

TreeStand.configure do
  config.parser_path = '../.'
end

parser   = TreeStand::Parser.new('c')
analyzer = Analyzer.new
inst     = Instrumentor.new

# Find .c files
paths = Dir.glob(File.join(source_dir, '**', '*.c')).sort
if paths.empty?
  warn "No .c files under: #{source_dir}"
  exit 2
end

# Build FileModels and Plans
file_models = []
file_plans  = []

paths.each do |p|
  src = File.binread(p)
  fm  = FileModel.new(path: p, src: src, parser: parser)
  plan = analyzer.analyze(fm)
  file_models << fm
  file_plans  << plan
end

# Plan edits (will error if multiple mains are detected)
begin
  inst.plan_edits(file_models: file_models, file_plans: file_plans)
rescue ArgumentError => e
  warn "Instrumentation planning failed: #{e.message}"
  exit 3
end

# Apply edits and write files under OUT_DIR, preserving structure
FileUtils.mkdir_p(out_dir)
results = inst.instrument_files

base = Pathname.new(File.expand_path(source_dir))
results.each do |r|
  abs   = Pathname.new(File.expand_path(r[:path]))
  rel   = abs.relative_path_from(base)
  out_p = File.join(out_dir, rel.to_s)
  FileUtils.mkdir_p(File.dirname(out_p))
  File.binwrite(out_p, r[:out])
  puts "instrumented #{rel}"
end

puts "\nWrote #{results.size} file(s) into #{out_dir}"
puts 'Compile with -O0 and run your program to produce coverage.lcov.'
