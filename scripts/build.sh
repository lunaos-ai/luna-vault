#!/usr/bin/env bash
set -euo pipefail

# Build VaultCore + CLI via SwiftPM. App is built via Xcode project (out of scope here).
cd "$(dirname "$0")/.."
swift build -c release
echo ""
echo "Built:"
echo "  CLI:    .build/release/vibevault"
echo "  Core:   .build/release/libVaultCore.dylib (linked into CLI)"
