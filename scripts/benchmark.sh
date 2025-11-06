#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
REPO_ROOT=$(cd "${SCRIPT_DIR}/.." && pwd)
SWIFT_ROOT="${REPO_ROOT}/swift"
PY_GENERATOR="${REPO_ROOT}/python/generate_test_library.py"

usage() {
  cat <<USAGE
Usage: $(basename "$0") [options]

Options:
  -n, --iterations <num>  Number of runs per implementation (default: 3)
      --go-args <args>    Extra arguments passed to the Go CLI (quoted string)
      --swift-args <args> Extra arguments passed to the Swift CLI (quoted string)
      --authors <num>     Number of authors per generated library (default: 10)
      --formats <list>    Comma-separated formats (default: pdf,epub,mobi,azw3,azw4)
      --keep-libraries    Preserve generated libraries (for inspection)
  -h, --help              Show this help message

Each run builds the Go and Swift CLIs (release equivalents) and, for every
iteration and implementation, generates a fresh sample library using
python/generate_test_library.py. Both CLIs are executed in dry-run mode, and the
script reports per-run timings alongside averages.
USAGE
}

ITERATIONS=3
GO_ARGS_EXTRA=""
SWIFT_ARGS_EXTRA=""
AUTHORS=10
FORMATS="pdf,epub,mobi,azw3,azw4"
KEEP_LIBS=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    -n|--iterations)
      ITERATIONS="$2"
      shift 2
      ;;
    --go-args)
      GO_ARGS_EXTRA="$2"
      shift 2
      ;;
    --swift-args)
      SWIFT_ARGS_EXTRA="$2"
      shift 2
      ;;
    --authors)
      AUTHORS="$2"
      shift 2
      ;;
    --formats)
      FORMATS="$2"
      shift 2
      ;;
    --keep-libraries)
      KEEP_LIBS=true
      shift 1
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unexpected argument: $1" >&2
      usage
      exit 1
      ;;
  esac
  if [[ $# -lt 0 ]]; then break; fi
done

if ! [[ "$ITERATIONS" =~ ^[0-9]+$ ]] || [[ "$ITERATIONS" -lt 1 ]]; then
  echo "Error: iterations must be a positive integer" >&2
  exit 1
fi

if ! [[ "$AUTHORS" =~ ^[0-9]+$ ]] || [[ "$AUTHORS" -lt 1 ]]; then
  echo "Error: authors must be a positive integer" >&2
  exit 1
fi

BENCH_DIR="${SWIFT_ROOT}/.bench"
mkdir -p "$BENCH_DIR"

uuid() {
  if command -v uuidgen >/dev/null 2>&1; then
    uuidgen
  else
    python3 - <<'PY'
import uuid
print(uuid.uuid4())
PY
  fi
}

generate_library() {
  local prefix="$1"
  local dest="${BENCH_DIR}/${prefix}_$(uuid)"
  python3 "$PY_GENERATOR" \
    --output "$dest" \
    --authors "$AUTHORS" \
    --formats "$FORMATS" \
    --force >/dev/null
  printf '%s\n' "$dest"
}

build_go() {
  >&2 echo "Building Go CLI..."
  pushd "$REPO_ROOT/golang" >/dev/null
  GO_BIN="${BENCH_DIR}/ebook-mechanic-go"
  go build -o "$GO_BIN" .
  popd >/dev/null
  printf '%s\n' "$GO_BIN"
}

build_swift() {
  >&2 echo "Building Swift CLI (release)..."
  pushd "$SWIFT_ROOT/EbookMechanicCLI" >/dev/null
  export SWIFT_MODULE_CACHE_PATH=.build/module-cache
  export CLANG_MODULE_CACHE_PATH=.build/module-cache
  swift build --configuration release --disable-sandbox --product EbookMechanicCLI >/dev/null
  BIN_DIR=$(swift build --configuration release --disable-sandbox --show-bin-path)
  popd >/dev/null
  printf '%s\n' "$BIN_DIR/EbookMechanicCLI"
}

sum_float() {
  python3 - "$1" "$2" <<'PY'
import sys
_, a, b = sys.argv
print(float(a) + float(b))
PY
}

avg_float() {
  python3 - "$1" "$2" <<'PY'
import sys
_, total, count = sys.argv
print(format(float(total) / float(count), '.4f'))
PY
}

run_cli() {
  local label="$1"
  local bin="$2"
  local dir_flag="$3"
  shift 3
  local -a base_args=("$@")
  local extra=""
  if [[ "$label" == "Go CLI" ]]; then
    extra="$GO_ARGS_EXTRA"
  else
    extra="$SWIFT_ARGS_EXTRA"
  fi

  printf '\n==> %s\n' "$label"
  local total=0.0
  for ((i=1; i<=ITERATIONS; i++)); do
    local library
    library=$(generate_library "${label// /_}_run${i}")

    local -a cmd=("$bin" "$dir_flag" "$library" "${base_args[@]}")
    if [[ -n "$extra" ]]; then
      local extra_arr=()
      read -r -a extra_arr <<< "$extra"
      cmd+=("${extra_arr[@]}")
    fi

    printf '  Run %d: ' "$i"
    local output
    if ! output=$( { /usr/bin/time -p "${cmd[@]}" >/dev/null; } 2>&1 ); then
      printf 'failed\n' >&2
      printf '%s\n' "$output" >&2
      $KEEP_LIBS || rm -rf "$library"
      exit 1
    fi
    local real
    real=$(printf '%s\n' "$output" | awk '$1=="real" {print $2}')
    if [[ -z "$real" ]]; then
      printf 'failed (unable to parse timing)\n' >&2
      printf '%s\n' "$output" >&2
      $KEEP_LIBS || rm -rf "$library"
      exit 1
    fi
    printf '%ss\n' "$real"
    total=$(sum_float "$total" "$real")
    $KEEP_LIBS || rm -rf "$library"
  done

  local avg
  avg=$(avg_float "$total" "$ITERATIONS")
  printf '  Average: %ss\n' "$avg"
}

GO_BIN=$(build_go)
SWIFT_BIN=$(build_swift)

run_cli "Go CLI" "$GO_BIN" "-dir" -dry-run -no-confirm -no-tui
run_cli "Swift CLI" "$SWIFT_BIN" "--dir" --dry-run --no-confirm --quiet

printf '\nBenchmark complete (iterations: %d).\n' "$ITERATIONS"
