# frozen_string_literal: true

module IPC
  # Handles the serialization and framing of messages between Parent and Workers.
  # Protocol: [4-byte Little Endian Length Header] + [Marshaled Payload]
  module Protocol
    def self.send(io, object)
      payload = Marshal.dump(object)
      # Pack size as unsigned long (32-bit), little-endian
      header = [payload.bytesize].pack('L<')
      io.write(header)
      io.write(payload)
    end

    def self.read(io)
      # Read 4-byte length header
      header = io.read(4)
      return nil unless header

      size = header.unpack1('L<')
      payload = io.read(size)
      return nil unless payload

      Marshal.load(payload)
    rescue EOFError, TypeError, ArgumentError
      # Return nil on corruption or EOF to signal connection close
      nil
    end
  end
end
