# frozen_string_literal: true

require_relative '../../spec_helper'
require_relative '../../../lib/minimize/worker_pool'

describe Minimization::WorkerPool do
  let(:pool_size) { 2 }
  let(:pool) { described_class.new(pool_size) }

  # Helper to create a pipe end mock that accepts standard IO calls
  def mock_pipe_end(name = 'pipe')
    double(name, close: nil, binmode: nil)
  end

  context 'Lifecycle management' do
    before do
      allow(pool).to receive(:fork).and_return(123, 124) # Fake PIDs
      allow(IO).to receive(:pipe).and_return([mock_pipe_end('r'), mock_pipe_end('w')])
    end

    it 'starts the correct number of workers' do
      pool.start! { raise 'Should not run in test parent' }

      expect(pool.instance_variable_get(:@workers).size).to eq(2)
    end

    it 'raises error if started twice' do
      pool.start! {}
      expect { pool.start! {} }.to raise_error('Workers already started')
    end

    it 'cleans up processes on shutdown' do
      pool.start! {}

      expect(Process).to receive(:kill).with('TERM', 123)
      expect(Process).to receive(:kill).with('TERM', 124)
      expect(Process).to receive(:waitpid).with(123)
      expect(Process).to receive(:waitpid).with(124)

      pool.shutdown
      expect(pool.instance_variable_get(:@workers)).to be_empty
    end
  end

  context 'Work distribution' do
    # Specific mocks for the ends we care about in tests
    let(:work_w) { mock_pipe_end('WorkWriter') }
    let(:stats_r) { mock_pipe_end('StatsReader') }

    before do
      # IO.pipe returns [read_end, write_end]
      # work pipe: [unused_read, work_w]
      # stats pipe: [stats_r, unused_write]
      allow(IO).to receive(:pipe).and_return(
        [mock_pipe_end, work_w],
        [stats_r, mock_pipe_end]
      )

      allow(pool).to receive(:fork).and_return(101, 102)
      pool.start! {}
    end

    it 'finds idle workers' do
      expect(pool.idle_workers.size).to eq(2)

      pool.instance_variable_get(:@workers).first.busy = true

      expect(pool.idle_workers.size).to eq(1)
    end

    it 'schedules work via Protocol' do
      worker = pool.idle_workers.first
      payload = { input: 'abc' }

      expect(IPC::Protocol).to receive(:send).with(worker.work_w, payload)

      pool.schedule_work(worker, payload)
      expect(worker.busy).to be(true)
    end

    it 'marks workers free' do
      worker = pool.idle_workers.first
      worker.busy = true

      pool.mark_free(worker.id)
      expect(worker.busy).to be(false)
    end
  end

  context 'Event polling' do
    let(:stats_r1) { mock_pipe_end('StatsReader1') }
    let(:stats_r2) { mock_pipe_end('StatsReader2') }

    before do
      # Setup 2 workers.
      allow(IO).to receive(:pipe).and_return(
        [mock_pipe_end, mock_pipe_end], [stats_r1, mock_pipe_end],
        [mock_pipe_end, mock_pipe_end], [stats_r2, mock_pipe_end]
      )

      allow(pool).to receive(:fork).and_return(101, 102)
      pool.start! {}
    end

    it 'returns empty array if no IO is ready' do
      allow(IO).to receive(:select).and_return(nil)
      expect(pool.poll_events).to eq([])
    end

    it 'returns events when data is available' do
      # Simulate stats_r1 having data
      allow(IO).to receive(:select).and_return([[stats_r1]])

      expected_msg = { type: :success }
      expect(IPC::Protocol).to receive(:read).with(stats_r1).and_return(expected_msg)

      events = pool.poll_events
      expect(events.size).to eq(1)
      expect(events.first[:message]).to eq(expected_msg)
      expect(events.first[:worker].id).to eq(1)
    end

    it 'handles nil message (worker death/EOF)' do
      allow(IO).to receive(:select).and_return([[stats_r1]])
      expect(IPC::Protocol).to receive(:read).with(stats_r1).and_return(nil)

      expect(pool.poll_events).to be_empty
    end
  end
end
