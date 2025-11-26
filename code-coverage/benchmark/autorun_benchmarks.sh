#!/usr/bin/env bash
# run_batch_microbench.sh
# Runs multiple (A, B, args...) triplets via run_microbench.sh
# and outputs the average Slow-down across all cases.
# Only final stdout line is: "Slow-down: <value>"

set -euo pipefail
export LC_ALL=C

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
MICRO="$SCRIPT_DIR/run_microbench.sh"

sum="0"
count=0

run_case() {
  local A="$1"; local B="$2"; shift 2
  # Forward optional -R if REPEAT is set
  local out
  if [[ -n "${REPEAT:-}" ]]; then
    out="$("$MICRO" -R "$REPEAT" "$A" "$B" "$@")"
  else
    out="$("$MICRO" "$A" "$B" "$@")"
  fi
  # Expect exactly: "Slow-down: <value>"
  local s
  s="$(printf '%s\n' "$out" | sed -n 's/^Slow-down: //p')"

  # Skip non-numeric (e.g., "inf") to avoid breaking the average
  if [[ -z "$s" || "$s" == "inf" ]]; then
    echo "warn: skipping non-numeric slowdown for [$A] vs [$B]: ${s:-<empty>}" >&2
    return 0
  fi

  # Accumulate with awk (float-safe)
  sum="$(awk -v a="$sum" -v b="$s" 'BEGIN{printf "%.9f", a+b}')"
  count=$((count+1))
}

### ---- HARD-CODED CASES (edit below) ----
run_case "../tests/test_source_files/test1/in"  "../tests/test_source_files/test1/out"
run_case "../tests/test_source_files/test2/in/" "../tests/test_source_files/test2/out/" -- 5
run_case "../tests/test_source_files/test3/in/" "../tests/test_source_files/test3/out/"
### ---------------------------------------

if (( count == 0 )); then
  echo "Slow-down: inf"
  exit 0
fi

avg="$(awk -v s="$sum" -v n="$count" 'BEGIN{printf "%.6f", s/n}')"
echo "Slow-down: $avg"

