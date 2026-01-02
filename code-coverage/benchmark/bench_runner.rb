#!/usr/bin/env ruby
# Usage: bench.rb <BIN_A> <BIN_B> [REPEAT] [-- ARGS...]

bin_a = ARGV.shift or abort "need BIN_A"
bin_b = ARGV.shift or abort "need BIN_B"

# Fixed amplification so sub-ms runs are measurable; override by arg or REPEAT env.
repeat =
  if ARGV[0] && ARGV[0] != "--"
    ARGV.shift.to_i
  elsif ENV["REPEAT"]
    ENV["REPEAT"].to_i
  else
    1000
  end
repeat > 0 or abort "REPEAT must be > 0"

args = if (i = ARGV.index("--")) then ARGV[(i+1)..-1] || [] else ARGV end

def time_block(bin, args, repeat)
  t0 = Process.clock_gettime(Process::CLOCK_MONOTONIC)
  repeat.times do
    pid = Process.spawn(bin, *args, out: File::NULL, err: File::NULL)
    _, st = Process.wait2(pid)
    exit 1 unless st.exitstatus == 0
  end
  t1 = Process.clock_gettime(Process::CLOCK_MONOTONIC)
  t1 - t0
end

ba = time_block(bin_a, args, repeat)
bb = time_block(bin_b, args, repeat)
a = ba / repeat.to_f
b = bb / repeat.to_f

ratio = (a == 0.0) ? Float::INFINITY : (b / a)
puts ratio.finite? ? "Slow-down: #{format('%.6f', ratio)}" : "Slow-down: inf"

