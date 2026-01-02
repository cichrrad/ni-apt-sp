#!/usr/bin/env bash
# Usage: ./run_microbench.sh [-R REPEAT] <A_DIR> <B_DIR> [-- ARGS...]
# Notes:
#  - Expects bench.rb to be in the same directory as this script.
#  - Only bench.rb prints output (final "Slow-down: <value>").

set -euo pipefail

REPEAT=""
while getopts ":R:h" opt; do
  case "$opt" in
    R) REPEAT="$OPTARG" ;;                       # per-binary repeat factor (optional)
    h) echo "Usage: $0 [-R REPEAT] <A_DIR> <B_DIR> [-- ARGS...]"; exit 0 ;;
    \?) echo "Unknown option: -$OPTARG" >&2; exit 2 ;;
    :)  echo "Option -$OPTARG requires an argument." >&2; exit 2 ;;
  esac
done
shift $((OPTIND-1))

(( $# >= 2 )) || { echo "Need A_DIR and B_DIR." >&2; exit 2; }
A_DIR=$1; B_DIR=$2; shift 2

# Everything after optional -- are program args
if [[ "${1-}" == "--" ]]; then shift; fi
PROGRAM_ARGS=( "$@" )

command -v gcc  >/dev/null || { echo "gcc not found."  >&2; exit 1; }
command -v ruby >/dev/null || { echo "ruby not found." >&2; exit 1; }

build_dir() {
  local dir="$1"
  (
    cd "$dir"
    # collect all .c files recursively and compile to ./program
    mapfile -d '' SRC < <(find . -type f -name '*.c' -print0)
    (( ${#SRC[@]} )) || { echo "No .c files in $dir" >&2; exit 1; }
    gcc -O0 "${SRC[@]}" -o program > benchmark_building.log 2>&1
  )
}

build_dir "$A_DIR"
build_dir "$B_DIR"

BIN_A="$A_DIR/program"
BIN_B="$B_DIR/program"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BENCH="$SCRIPT_DIR/bench_runner.rb"

# Run the Ruby bench; ensure our script itself prints nothing.
if [[ -n "$REPEAT" ]]; then
  exec ruby "$BENCH" "$BIN_A" "$BIN_B" "$REPEAT" -- "${PROGRAM_ARGS[@]}"
else
  exec ruby "$BENCH" "$BIN_A" "$BIN_B" -- "${PROGRAM_ARGS[@]}"
fi
