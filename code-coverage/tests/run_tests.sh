#!/usr/bin/env bash
set -euo pipefail
shopt -s nullglob


root="test_source_files"
last_line_coverage=""

for d in "$root"/*/; do
  [[ -d "$d" ]] || continue

  in="$d/in"
  out="$d/out"

  # Ensure output dir exists
  mkdir -p "$out"

  # 1) Instrument
  name="$(basename "$d")"
  output=$(COVERAGE=true COVERAGE_NAME="test:$name" ./instrument.rb "$in" "$out")
  echo "$output"

  line_cov=$(echo "$output" | grep -oE "Line Coverage: [0-9]+\.[0-9]+%")
  if [[ -n "$line_cov" ]]; then
    last_line_coverage="$line_cov"
  fi
  # 2) Copy headers
  if compgen -G "$in/*.h" > /dev/null; then
    cp "$in"/*.h "$out"/
  fi

  # 3) Compile all .c files in out to 'program'
  (
    cd "$out"
    c_files=( *.c )
    if ((${#c_files[@]})); then

    gcc -O0 "${c_files[@]}" -o program > build.output 2>&1 \
      || { echo "Build failed in $out. build.output:" >&2; cat build.output >&2; exit 1; }

    ./program > prog.output 2>&1 \
      || { echo "Program failed in $out. prog.output:" >&2; cat prog.output >&2; exit 1; }

    else
      echo "No .c files in $out; skipping compilation." >&2
    fi
  )

done

if [[ -n "$last_line_coverage" ]]; then
  echo "$last_line_coverage" > coverage.txt
  echo "Saved $last_line_coverage to coverage.txt"
else
  echo "No coverage information found." > coverage.txt
fi

mv coverage.txt ../coverage.txt

echo "== Running RSpec =="
bundle exec rspec -fd --backtrace comp_spec.rb