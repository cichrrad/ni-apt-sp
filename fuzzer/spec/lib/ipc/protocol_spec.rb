# frozen_string_literal: true

require_relative '../../spec_helper'
require_relative '../../../lib/ipc/protocol'

describe IPC::Protocol do
  let(:dummy_object) { { type: :test, data: 'hello' } }
  let(:marshaled_data) { Marshal.dump(dummy_object) }
  let(:payload_size) { marshaled_data.bytesize }
  let(:packed_header) { [payload_size].pack('L<') }

  context '.send' do
    let(:io) { StringIO.new }

    it 'writes the 4-byte header followed by the marshaled payload' do
      described_class.send(io, dummy_object)

      io.rewind
      output = io.read

      # Expect Header + Payload
      expect(output.bytesize).to eq(4 + payload_size)
      expect(output[0, 4]).to eq(packed_header)
      expect(output[4..]).to eq(marshaled_data)
    end
  end

  context '.read' do
    it 'reads the header and extracts the payload correctly' do
      # Simulate a pipe containing [HEADER][PAYLOAD]
      input_stream = StringIO.new(packed_header + marshaled_data)

      result = described_class.read(input_stream)
      expect(result).to eq(dummy_object)
    end

    it 'returns nil if EOF occurs while reading header' do
      empty_stream = StringIO.new('')
      expect(described_class.read(empty_stream)).to be_nil
    end

    it 'returns nil if EOF occurs while reading payload' do
      # Header promises X bytes, but stream ends immediately
      broken_stream = StringIO.new(packed_header)
      expect(described_class.read(broken_stream)).to be_nil
    end

    it 'handles standard errors gracefully' do
      # Simulate an IO error
      bad_io = double('IO')
      allow(bad_io).to receive(:read).and_raise(EOFError)

      expect(described_class.read(bad_io)).to be_nil
    end
  end
end
