#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
LOG=$(mktemp -t uppy-verification)
trap 'rm -f "$LOG"' EXIT
run_gate() {
  for target in format lint clean test app; do
    make "$target" || return 1
  done
  if [[ "$(xcode-select -p)" == *.app/Contents/Developer ]]; then
    swift test -Xswiftc -warnings-as-errors -Xlinker -fatal_warnings || return 1
  fi
}
if ! run_gate 2>&1 | tee "$LOG"; then
  echo "FAIL: verification command failed. See diagnostics above." >&2
  exit 1
fi
if grep -Ei '(^|[[:space:]])(warning|error):' "$LOG"; then
  echo "FAIL: warnings or errors remain. Fix the cause; do not suppress diagnostics." >&2
  exit 1
fi
echo "PASS: formatting, lint, clean builds, tests, packaging, and signing; zero warnings."
