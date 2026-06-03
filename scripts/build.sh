#!/usr/bin/env bash
set -euo pipefail

# Build VaultCore + CLI via SwiftPM. App is built via Xcode project (out of scope here).
cd "$(dirname "$0")/.."
swift build -c release

# Sign CLI binaries with entitlements for shared Keychain access group.
ARCH=$(uname -m)
BIN_DIR=".build/${ARCH}-apple-macosx/release"
codesign --force --sign - --entitlements cli/vibevault/vibevault.entitlements "$BIN_DIR/vibevault"
codesign --force --sign - --entitlements cli/vibevault-mcp/vibevault-mcp.entitlements "$BIN_DIR/vibevault-mcp"

echo ""
echo "Built + signed:"
echo "  CLI:    $BIN_DIR/vibevault"
echo "  MCP:    $BIN_DIR/vibevault-mcp"
echo "  Core:   $BIN_DIR/libVaultCore.dylib (linked into CLI)"
