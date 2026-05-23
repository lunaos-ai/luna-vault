#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."
swift test --enable-code-coverage

PROF=$(find .build -name "*.profdata" | head -n1)
BIN=$(find .build -name "VaultCoreTests.xctest" | head -n1)/Contents/MacOS/VaultCoreTests
if [ -z "$PROF" ] || [ -z "$BIN" ]; then
    echo "coverage artifacts not found"
    exit 1
fi

xcrun llvm-cov report \
    -instr-profile="$PROF" \
    -ignore-filename-regex='Tests|\.build' \
    "$BIN"
