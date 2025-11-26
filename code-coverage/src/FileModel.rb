# frozen_string_literal: true

require 'tree_stand'

# Snapshot of a C source file:
# - raw bytes
# - parsed AST (TreeStand)
# - byte <--> line helper functions
class FileModel
  attr_reader :path, :source, :root, :line_count

  def initialize(path:, src:, parser:)
    @path   = File.expand_path(path).freeze
    @source = ensure_utf8_bytes(src).freeze
    tree    = parser.parse_string(@source)
    @root   = tree.root_node

    @line_starts = compute_line_starts(@source) # byte offsets where each line starts
    @line_count  = @line_starts.length
    @eof_byte    = @source.bytesize
  end

  # ---------------- byte/line helpers ----------------

  # [start_byte, end_byte) for a node
  def byte_range(node)
    r = node.range
    [r.start_byte, r.end_byte]
  end

  # byteslice (overload to always do it on source)
  def byteslice(start_byte, end_byte)
    @source.byteslice(start_byte...end_byte)
  end

  def text_for(node)
    s, e = byte_range(node)
    byteslice(s, e)
  end

  def line_of(node)
    node.range.start_point.row + 1
  end

  # ---------------- AST related ----------------

  # All function_definition nodes in this file
  def functions
    out = []
    walk(@root) { |n| out << n if node_type(n) == 'function_definition' }
    out
  end

  def first_non_decl_in(body_node)
    raise ArgumentError, 'body_node must be compound_statement' unless node_type(body_node) == 'compound_statement'

    kids = named_children(body_node)
    return body_node.range.start_byte + 1 if kids.empty? # right after '{'

    last_decl_end = nil
    kids.each do |ch|
      return last_decl_end || body_node.range.start_byte + 1 unless node_type(ch) == 'declaration'

      last_decl_end = ch.range.end_byte
    end
    last_decl_end || (body_node.range.start_byte + 1)
  end

  # ---------------- Private methods ----------------

  private

  # cast symbols to str
  def node_type(node)
    t = node.type
    t.is_a?(Symbol) ? t.to_s : t
  end

  # NEEDED to ensure new line is 2 bytes ('10')
  def ensure_utf8_bytes(str)
    s = str.dup
    s.force_encoding(Encoding::UTF_8)
    s
  end

  # Byte offsets where each line starts
  def compute_line_starts(src)
    starts = [0]
    b = src.bytes
    i = 0
    while i < b.length
      starts << (i + 1) if b[i] == 10 && (i + 1) < b.length # 10 == "\n"
      i += 1
    end
    starts
  end

  # upper_bound: first index with arr[idx] > value
  def upper_bound(arr, value)
    lo = 0
    hi = arr.length
    while lo < hi
      mid = (lo + hi) / 2
      if arr[mid] <= value
        lo = mid + 1
      else
        hi = mid
      end
    end
    lo
  end

  def check_line!(line_no)
    return if (1..@line_starts.length).cover?(line_no)

    raise ArgumentError, "line out of range: #{line_no} (1..#{@line_starts.length})"
  end

  # Return only "named" children (skip punctuation like '{', '}', ';')
  def named_children(node)
    node.children.select do |c|
      c.respond_to?(:named?) ? c.named? : !!(node_type(c) =~ /\A[a-z_]/i)
    end
  end

  # Iterative DFS over named children
  def walk(node)
    stack = [node]
    until stack.empty?
      n = stack.pop
      yield n
      kids = named_children(n)
      (kids.length - 1).downto(0) { |i| stack << kids[i] }
    end
  end

  def safe_field(node, name_sym)
    node.respond_to?(name_sym) ? node.public_send(name_sym) : nil
  end
end
