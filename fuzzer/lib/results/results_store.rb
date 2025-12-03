# frozen_string_literal: true

require 'json'
require 'fileutils'
require 'digest'

module Results
  # Saves individual crash and hang reports
  class ResultsStore
    CRASHES_DIR = 'crashes'
    HANGS_DIR = 'hangs'

    def initialize(root_dir:)
      @root_dir = root_dir
      @crashes_path = File.join(@root_dir, CRASHES_DIR)
      @hangs_path = File.join(@root_dir, HANGS_DIR)

      # pre-create
      FileUtils.mkdir_p(@crashes_path)
      FileUtils.mkdir_p(@hangs_path)
    end

    # Save report for new bug
    def save_report(classification:,
                    run_result:,
                    minimized_input:, unminimized_size:, min_result: nil, coverage: 0)
      report = build_report(
        classification: classification,
        run_result: run_result,
        min_result: min_result,
        minimized_input: minimized_input,
        unminimized_size: unminimized_size,
        coverage: coverage
      )

      # Where to place ?
      target_dir = classification.hang? ? @hangs_path : @crashes_path
      filename = generate_filename(classification)
      save_path = File.join(target_dir, filename)

      # Write the file
      File.write(save_path, JSON.pretty_generate(report))
    end

    private

    def build_report(classification:, run_result:, min_result:, minimized_input:, unminimized_size:, coverage:)
      report = {
        input: minimized_input,
        oracle: classification.oracle.to_s,
        bug_info: classification.bug_info,
        coverage: coverage,
        execution_time: run_result.wall_time_ms
      }

      report[:minimization] = build_minimization_block(min_result, unminimized_size) if min_result

      report
    end

    # adds minimization data to json
    def build_minimization_block(min_result, unminimized_size)
      {
        unminimized_size: unminimized_size,
        nb_steps: min_result.nb_steps,
        execution_time: min_result.exec_time_ms
      }
    end

    # Generates files with uuid-ish mangled names
    def generate_filename(classification)
      sig_hash = Digest::SHA256.hexdigest(classification.signature)[0, 10]
      timestamp = (Time.now.to_f * 1000).to_i

      "#{timestamp}-#{sig_hash}.json"
    end
  end
end
