#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."
swift test --enable-code-coverage

PROF=$(find .build -name "*.profdata" | head -n1)
TEST_BUNDLE=$(find .build -name "*.xctest" -type d | head -n1)
BIN=""
if [ -n "$TEST_BUNDLE" ]; then
    BIN=$(find "$TEST_BUNDLE/Contents/MacOS" -type f -perm -111 | head -n1)
fi
if [ -z "$PROF" ] || [ -z "$BIN" ]; then
    echo "coverage artifacts not found"
    exit 1
fi

xcrun llvm-cov report \
    -instr-profile="$PROF" \
    -ignore-filename-regex='Tests|\.build' \
    "$BIN"
