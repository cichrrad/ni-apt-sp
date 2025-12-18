# frozen_string_literal: true

require_relative '../ipc/protocol'

module Minimization
  # Manages a pool of forked worker processes.
  # Handles pipes and lifecycle (fork/kill).
  class WorkerPool
    # Internal tracking struct
    WorkerSlot = Struct.new(:pid, :work_w, :stats_r, :busy, :id, keyword_init: true)

    def initialize(count)
      @count = count
      @workers = []
    end

    # Spawns workers.
    # The block passed here is executed INSIDE the child process.
    # Block signature: |worker_id, pipe_read_for_work, pipe_write_for_stats|
    def start!(&worker_logic_block)
      raise 'Workers already started' unless @workers.empty?

      @count.times do |i|
        id = i + 1
        work_r, work_w = IO.pipe
        stats_r, stats_w = IO.pipe

        work_w.binmode
        stats_w.binmode

        # --- CHILD PROCESS ---
        pid = fork do
          # shut child up
          Signal.trap('INT') { exit!(0) }
          Signal.trap('TERM') { exit!(0) }

          # Close unused ends
          work_w.close
          stats_r.close

          # Run the worker logic (point of no return)
          worker_logic_block.call(id, work_r, stats_w)
        end
        # --- END CHILD ---

        # Close unused ends
        work_r.close
        stats_w.close

        @workers << WorkerSlot.new(
          pid: pid,
          work_w: work_w,
          stats_r: stats_r,
          busy: false,
          id: id
        )
      end
    end

    # Returns an array of available worker objects (or empty)
    def idle_workers
      @workers.reject(&:busy)
    end

    # Sends work to a specific worker and marks it busy
    def schedule_work(worker_slot, payload)
      worker_slot.busy = true
      IPC::Protocol.send(worker_slot.work_w, payload)
    end

    # Marks a worker as free (to be called when job completes)
    def mark_free(worker_id)
      w = @workers.find { |x| x.id == worker_id }
      w.busy = false if w
    end

    # Non-blocking check for messages from ANY worker.
    # Returns Array of { worker: slot, message: msg }
    def poll_events
      # Map to raw IO objects for select
      readable_pipes = @workers.map(&:stats_r)

      # Non-blocking select
      ready, = IO.select(readable_pipes, nil, nil, 0)
      return [] unless ready

      events = []
      ready.each do |pipe|
        worker = @workers.find { |w| w.stats_r == pipe }
        next unless worker

        msg = IPC::Protocol.read(pipe)
        # If msg is nil, the pipe broke (worker crashed/died)
        # In a robust system, we would restart the worker here.
        next if msg.nil?

        events << { worker: worker, message: msg }
      end
      events
    end

    def shutdown
      # Kill workers
      @workers.each do |w|
        Process.kill('TERM', w.pid)
      rescue Errno::ESRCH
        # already dead
      end

      # Reap zombies
      @workers.each do |w|
        Process.waitpid(w.pid)
      rescue Errno::ECHILD, Errno::ESRCH
        nil
      end

      # Close pipes
      @workers.each do |w|
        begin
          w.work_w.close
        rescue StandardError
          nil
        end
        begin
          w.stats_r.close
        rescue StandardError
          nil
        end
      end
      @workers.clear
    end
  end
end
