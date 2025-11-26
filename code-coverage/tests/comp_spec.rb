require 'rspec'

RSpec.describe 'coverage.lcov content' do
  def read_lines(path)
    File.read(path, mode: 'r:bom|utf-8')
        .gsub("\r\n", "\n")
        .split("\n", -1) # keep trailing empty line if present
  end

  def expect_range_to_include(lines, range, expectations, trim: true, ignore_blank: true)
    exp_lines = expectations.lines.map { |l| l.chomp }
    exp_lines.map!(&:strip) if trim
    exp_lines.reject!(&:empty?) if ignore_blank

    raise ArgumentError, "Range length (#{range.size}) != expectations count (#{exp_lines.size})" \
      unless range.size == exp_lines.size

    range.each_with_index do |line_no, i|
      content = lines.fetch(line_no - 1) { raise "Line #{line_no} out of range (file has #{lines.length} lines)" }
      content = content.strip if trim
      expect(content).to include(exp_lines[i])
    end
  end

  it 'test1' do
    path = './test_source_files/test1/out/coverage.lcov'
    expect(File).to exist(path)

    lines = read_lines(path)

    expect_range_to_include(lines, 3..10, <<~LCOV)
      DA:8
      DA:9
      DA:11
      DA:13
      DA:18
      DA:19
      LH:6
      LF:7
    LCOV
  end

  it 'test2 (no input)' do
    path = './test_source_files/test2/out/coverage.lcov'
    expect(File).to exist(path)

    lines = read_lines(path)

    expect_range_to_include(lines, 3..7, <<~LCOV)
      DA:17
      DA:19
      DA:28
      LH:3#{' '}
      LF:9#{' '}
    LCOV
  end

  it 'multi file test 1' do
    path = './test_source_files/test3/out/coverage.lcov'
    expect(File).to exist(path)

    lines = read_lines(path)

    expect_range_to_include(lines, 3..9, <<~LCOV)
      DA:5
      DA:6
      DA:8
      DA:9
      DA:11
      LH:5#{' '}
      LF:5#{' '}
    LCOV

    expect_range_to_include(lines, 12..15, <<~LCOV)
      DA:3
      DA:5
      LH:2#{' '}
      LF:2#{' '}
    LCOV
  end
end
