# frozen_string_literal: true

require 'digest/sha1'

# singular change made to a file
# 2 kinds --> :insert, :replace
# :insert -- inserts :text at offset :a
# :replace -- replaces bytes at range :a -- :b with :text
Edit = Struct.new(:kind, :a, :b, :text, keyword_init: true)

class Instrumentor
  # Array of files, where each file has
  #   model: FileModel,
  #   plan: FilePlan,
  #   file_id: see below,
  #   edits: [Edit, ...],
  #   out: instrumented .c file
  #   (generated in method instrument_files)
  attr_reader :files

  def initialize(file_id_gen: nil)
    # generator of 'uuid' for each .c file
    # appended after name to prevent any clashing
    @file_id_gen = file_id_gen || lambda { |path|
      base = File.basename(path).gsub(/[^A-Za-z0-9]/, '_')
      hash = Digest::SHA1.hexdigest(path)[0, 8]
      "#{base}_#{hash}"
    }
    @files = []
  end

  def plan_edits(file_models:, file_plans:)
    raise ArgumentError, 'file_models and file_plans must be arrays of same length' \
   unless file_models.is_a?(Array) && file_plans.is_a?(Array) && file_models.length == file_plans.length

    # find main TU (no more than 1!)
    mains = file_plans.each_index.select { |i| file_plans[i].has_main }
    raise ArgumentError, "Multiple files with 'main' detected (indexes: #{mains.inspect})" if mains.length > 1

    # give out 'uuid's
    all_file_ids = file_plans.map { |fp| @file_id_gen.call(fp.path) }

    # build edits for all files
    file_models.zip(file_plans).each do |fm, fp|
      file_id = @file_id_gen.call(fm.path)
      edits = []

      # instrument lines we noted
      # in file plans for this file
      # (Analyzer.rb)
      edits.concat edits_for_sites(fm, fp, file_id)

      # add prologue (includes, declarations,...) to this file + in main file we also fetch
      # other TUs and define our exit function which will write the .lcov in atexit call
      header = String.new
      header << prologue(fm, fp, file_id)
      if fp.has_main
        fwd_decls = all_file_ids.map { |fid| "extern void __apt_register_#{fid}(void);" }.join("\n")
        header << "/* __APT_COV__ fwd decls */\n#{fwd_decls}\n"
        header << runtime
      end
      # insert at 0 cuz this will be at the very top
      # (it has includes and vars for all the counting)
      edits << Edit.new(kind: :insert, a: 0, text: header)

      # additionaly in main file, inject
      # atexit(__apt_write_lcov) + register
      # all other TUs
      if fp.has_main
        regs = all_file_ids.map { |fid| "__apt_register_#{fid}();" }.join("\n")
        init_calls = "/* __APT_COV__ init */ atexit(__apt_write_lcov);\n#{regs}\n"
        edits << Edit.new(kind: :insert, a: fp.main_anchor, text: init_calls)
      end

      # order edits so we edit files bottom-up
      # --> offsets dont shift
      edits = sort_edits_desc(edits)

      @files << { model: fm, plan: fp, file_id: file_id, edits: edits }
    end

    self
  end

  # generate instrumented files
  def instrument_files
    @files.map! do |entry|
      fm    = entry[:model]
      edits = entry[:edits]
      out   = apply_edits(fm.source, edits)
      entry.merge(out: out, path: fm.path)
    end
  end

  private

  # instrument files at noted sites
  # for :pre --> just place increment
  # right before
  #
  # for :cond_* --> replace with comma expression
  # where we increment and just forward
  # the original condition
  def edits_for_sites(file_model, file_plan, file_id)
    edits = []
    file_plan.sites.each do |s|
      line = s.line
      case s.kind
      # :pre
      when :pre
        off = s.node.range.start_byte
        edits << Edit.new(
          kind: :insert,
          a: off,
          text: "__apt_hits_#{file_id}[#{line}]++; /*__APT_COV__*/ "
        )
      # :cond_*
      when :cond_if, :cond_while, :cond_for
        cond   = s.aux[:cond_node]
        startb = cond.range.start_byte
        endb   = cond.range.end_byte
        orig   = file_model.text_for(cond)
        wrapped = parenthesized?(orig) ? orig : "(#{orig})"
        repl = "(__apt_hits_#{file_id}[#{line}]++, #{wrapped})"
        edits << Edit.new(kind: :replace, a: startb, b: endb, text: repl)
      end
    end
    edits
  end

  # build prologue for a file
  def prologue(file_model, file_plan, file_id)
    n = file_plan.nlines + 1 # 1-based

    # mask mapping out (with 1s)
    # all instrumented lines in this file
    mask = Array.new(n, 0)
    file_plan.instrument_lines.each { |line| mask[line] = 1 }

    c_path = escape_c_string(file_model.path)

    # actual C code that will be injected
    <<~C
      /* __APT_COV__ prologue begin */
      #include <stdio.h>
      #include <stdlib.h>
      struct __apt_file { const char *path; unsigned long *hits; int nlines; const unsigned char *mask; };
      void __apt_register(struct __apt_file*);
      static unsigned long __apt_hits_#{file_id}[#{n}] = {0};
      static const unsigned char __apt_mask_#{file_id}[#{n}] = { #{mask.join(',')} };
      static struct __apt_file __apt_me_#{file_id} = { "#{c_path}", __apt_hits_#{file_id}, #{n - 1}, __apt_mask_#{file_id} };
      void __apt_register_#{file_id}(void) { __apt_register(&__apt_me_#{file_id}); }
      /* __APT_COV__ prologue end */
    C
  end

  # inject runtime header only in main file
  # specifies:
  #   > array for 512 files (~TUs)
  #   > number of files
  #   > file register func
  #   > writer func which will
  #     save results upon atexit()
  def runtime
    <<~C
      /* __APT_COV__ runtime begin */
      #ifndef __APT_RUNTIME_ONCE
      #define __APT_RUNTIME_ONCE
      #include <stdio.h>
      #include <stdlib.h>
      static struct __apt_file* __apt_files[512];
      static int __apt_nfiles = 0;
      void __apt_register(struct __apt_file* f) {
        if (__apt_nfiles < (int)(sizeof(__apt_files)/sizeof(__apt_files[0]))) __apt_files[__apt_nfiles++] = f;
      }
      static void __apt_write_lcov(void) {
        FILE *fp = fopen("coverage.lcov", "w");
        if (!fp) return;
        fprintf(fp, "TN:test\\n");
        for (int i = 0; i < __apt_nfiles; i++) {
          struct __apt_file *f = __apt_files[i];
          fprintf(fp, "SF:%s\\n", f->path);
          int LF = 0, LH = 0;
          for (int line = 1; line <= f->nlines; line++) {
            if (!f->mask[line]) continue;
            LF++;
            unsigned long c = f->hits[line];
            if (c) { fprintf(fp, "DA:%d,%lu\\n", line, c); LH++; }
          }
          fprintf(fp, "LH:%d\\nLF:%d\\nend_of_record\\n", LH, LF);
        }
        fclose(fp);
      }
      #endif
      /* __APT_COV__ runtime end */
    C
  end

  def apply_edits(source, edits)
    s = source.dup
    edits.each do |e|
      case e.kind
      when :replace
        s = s.byteslice(0...e.a) + e.text + s.byteslice(e.b...s.bytesize)
      when :insert
        s = s.byteslice(0...e.a) + e.text + s.byteslice(e.a...s.bytesize)
      else
        raise "Unknown edit kind: #{e.kind}"
      end
    end
    s
  end

  # Helpers

  # is str wrapped by a single outer pair of brackets?
  def parenthesized?(str)
    t = str.strip
    return false unless t.start_with?('(') && t.end_with?(')')

    depth = 0
    t.chars.each_with_index do |ch, i|
      depth += 1 if ch == '('
      depth -= 1 if ch == ')'
      return false if depth.zero? && i < t.length - 1
    end
    depth.zero?
  end

  # escape Ruby string to a C string literal
  def escape_c_string(str)
    str.gsub('\\', '\\\\').gsub('"', '\"')
  end

  # sorting edits by offset (desc) + tie breaking
  def sort_edits_desc(edits)
    # for ties, :replace before :insert
    edits.sort_by { |e| [-e.a, (e.kind == :replace ? 0 : 1)] }
  end
end
