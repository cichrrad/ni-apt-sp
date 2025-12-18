# frozen_string_literal: true

require 'colorize'

module CLI
  class Reporter
    def log_startup(config, worker_count)
      puts '--- Fuzzer Starting (Multi-Process Mode) ---'.bold
      puts "  Target:    #{config.fuzzed_program.light_blue}"
      puts "  Workers:   #{worker_count.to_s.light_blue}"
      puts "  Minimize:  #{config.minimize_enabled?.to_s.light_blue}"
      puts '-----------------------'
    end

    def log_new_bug(classification)
      puts "\n#{'--- NEW FAILURE FOUND! ---'.red.bold}"
      puts "  Oracle:    #{classification.oracle.to_s.red}"
      puts "  Signature: #{classification.signature.red}"
      puts "  Status:    #{'Queued for minimization.'.yellow}"
      puts "-----------------------\n"
    end

    def log_new_bug_during_min(classification)
      puts '  -> Discovered new bug during minimization!'.magenta
      puts "     Signature: #{classification.signature.magenta}"
      puts '     Sent to queue.'.magenta
    end

    def log_minimization_done(classification, old_size, new_size)
      puts '--- Minimization Complete ---'.green
      puts "  Signature: #{classification.signature.cyan}"
      puts "  Size:      #{old_size} bytes -> #{new_size} bytes".green
      puts '  Report saved.'.green
      puts '-----------------------------'
    end

    def log_info(msg)
      puts "[INFO] #{msg}".light_black
    end

    def log_warn(msg)
      puts "[WARN] #{msg}".yellow
    end

    def log_error(msg)
      puts "[ERROR] #{msg}".red
    end

    def log_success(msg)
      puts "[OK] #{msg}".green
    end

    def log_progress(count)
      log_info("Fuzzed #{count} inputs.")
    end
  end
end
