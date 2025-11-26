# frozen_string_literal: true

InstrumentSite = Struct.new(:kind, :line, :node, :aux, keyword_init: true)
FilePlan       = Struct.new(:path, :nlines, :instrument_lines, :sites, :main_anchor, :has_main, keyword_init: true)

# Analyzes AST using FileModel
# - tries to find main
#   > if found, it finds anchor for atexit
# - walks the AST (processes all functions)
# - identifies lines to instrument
# - return 'Plan' for the file processed
class Analyzer
  # Tree Sitter token names for exec
  EXEC_PRE_TYPES  = %w[expression_statement return_statement break_statement continue_statement goto_statement
                       declaration].freeze
  EXEC_HEAD_TYPES = %w[if_statement while_statement for_statement].freeze

  def analyze(file_model)
    sites       = []
    # to prevent duplicate counts
    # for lines like 'x++; y++;'
    seen_lines  = {}
    has_main    = false
    main_anchor = nil

    file_model.functions.each do |fn|
      # Is this main?
      if (id = find_identifier_in(fn)) && file_model.text_for(id) == 'main'
        has_main   = true
        body       = fn.respond_to?(:body) ? fn.body : nil
        main_anchor ||= file_model.first_non_decl_in(body) if body
      end

      body = fn.respond_to?(:body) ? fn.body : nil

      # =next IF NOT body (I love ruby)
      next unless body

      # now we are in function body
      # n is yielded value from the stack of nodes in main
      walk_named(body) do |n|
        type = n.type.to_s
        # is this ast node exec header (if/while/for)?
        if EXEC_HEAD_TYPES.include?(type)
          line = file_model.line_of(n)
          # filters out anything BUT (if/while/for)
          # constructs InstrumentSite with meta information
          # OR returns nil if filtered out
          site = header_site(n, line)
          # especially check for 'for' with no conditions --> gets :pre (1 count) instead of :cond_for (1 count / iter)
          site ||= (type == 'for_statement' ? InstrumentSite.new(kind: :pre, line: line, node: n) : nil) # for(;;)

          # log this into sites
          accept_site!(sites, seen_lines, site) if site
          # gimme another n
          next
        end

        # Ordinary executable statements --> pre-increment, unless labeled (would break gotos,switches)
        if EXEC_PRE_TYPES.include?(type)
          next if labeled_context?(n) # don't steal the label's statement

          line = file_model.line_of(n)
          accept_site!(sites, seen_lines, InstrumentSite.new(kind: :pre, line: line, node: n))
        end
      end
    end

    # sort and dedup sites by their :line symbol (--> only 1 site per line)
    lines = sites.map(&:line).uniq.sort
    FilePlan.new(
      path: file_model.path,
      nlines: file_model.line_count,
      instrument_lines: lines,
      sites: sites.sort_by { |s| [s.line, s.node.range.start_byte] },
      main_anchor: main_anchor,
      has_main: has_main
    )
  end

  private

  # Only "named" children (skip punctuation like {, }, ;)
  def named_children(node)
    node.children.select { |c| c.respond_to?(:named?) ? c.named? : !!(c.type.to_s =~ /\A[a-z_]/i) }
  end

  def walk_named(node)
    stack = [node]
    until stack.empty?
      n = stack.pop
      yield n
      kids = named_children(n)
      (kids.length - 1).downto(0) { |i| stack << kids[i] }
    end
  end

  # go through function children
  # until I find identifier node
  def find_identifier_in(fn_def)
    node = fn_def.respond_to?(:declarator) ? fn_def.declarator : nil
    while node && node.type.to_s != 'identifier'
      node = (node.respond_to?(:declarator) ? node.declarator : nil) || named_children(node).first
    end
    node
  end

  def header_site(stmt, line)
    kind = stmt.type.to_s
    cond = stmt.respond_to?(:condition) ? stmt.condition : nil
    return nil unless cond

    k = case kind
        when 'if_statement'    then :cond_if
        when 'while_statement' then :cond_while
        when 'for_statement'   then :cond_for
        end
    InstrumentSite.new(kind: k, line: line, node: stmt, aux: { cond_node: cond })
  end

  # We want one site per line
  def accept_site!(sites, seen, site)
    return unless site

    l = site.line
    # if seen already, we prefer conditions
    # because of lines like `if(cond) return ret`
    if seen[l]
      prev = seen[l]
      if prev.kind == :pre && site.kind != :pre
        seen[l] = site
        idx = sites.index(prev)
        sites[idx] = site if idx
      end
    else
      # if not seen, note
      seen[l] = site
      sites << site
    end
  end

  # If a node is immediately under a label/case/default, skip to not break gotos
  def labeled_context?(node)
    p = node.respond_to?(:parent) ? node.parent : nil
    return false unless p

    t = p.type.to_s
    %w[labeled_statement case_statement default_statement].include?(t)
  end
end
