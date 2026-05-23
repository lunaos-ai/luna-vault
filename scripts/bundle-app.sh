#!/usr/bin/env bash
set -euo pipefail

# Wrap the SwiftPM-built VibeVaultApp + vibevault-mcp into a .app bundle so
# MenuBarExtra, Info.plist, entitlements, and AI-client integration work
# correctly.
# Output: build/VibeVault.app

cd "$(dirname "$0")/.."

CONFIG="${1:-debug}"   # debug | release
case "$CONFIG" in
    debug) SWIFT_BUILD_FLAGS="" ;;
    release) SWIFT_BUILD_FLAGS="-c release" ;;
    *) echo "usage: $0 [debug|release]"; exit 64 ;;
esac

echo "==> Building VibeVaultApp + vibevault-mcp ($CONFIG)..."
swift build $SWIFT_BUILD_FLAGS --product VibeVaultApp
swift build $SWIFT_BUILD_FLAGS --product vibevault-mcp
swift build $SWIFT_BUILD_FLAGS --product vibevault

ARCH=$(uname -m)
BIN_DIR=".build/${ARCH}-apple-macosx/${CONFIG}"
APP_BIN="$BIN_DIR/VibeVaultApp"
MCP_BIN="$BIN_DIR/vibevault-mcp"
CLI_BIN="$BIN_DIR/vibevault"

for f in "$APP_BIN" "$MCP_BIN" "$CLI_BIN"; do
    if [ ! -x "$f" ]; then
        echo "error: binary not found at $f"; exit 1
    fi
done

APP_DIR="build/VibeVault.app"
echo "==> Bundling to $APP_DIR..."
rm -rf "$APP_DIR"
mkdir -p "$APP_DIR/Contents/MacOS" "$APP_DIR/Contents/Resources"

cp "$APP_BIN" "$APP_DIR/Contents/MacOS/VibeVault"
cp "$MCP_BIN" "$APP_DIR/Contents/MacOS/vibevault-mcp"
mkdir -p "$APP_DIR/Contents/Helpers"
cp "$CLI_BIN" "$APP_DIR/Contents/Helpers/vibevault"
cp apps/VibeVaultApp/Info.plist "$APP_DIR/Contents/Info.plist"

/usr/libexec/PlistBuddy -c "Set :CFBundleExecutable VibeVault" "$APP_DIR/Contents/Info.plist" 2>/dev/null || true

# Ad-hoc sign so MenuBarExtra/LAContext/Keychain work without Developer ID.
codesign --force --deep --sign - "$APP_DIR" 2>&1 | sed 's/^/  codesign: /'

echo ""
echo "==> Done."
echo "    open $APP_DIR"
echo ""
echo "    Bundled binaries:"
echo "      VibeVault       (app)"
echo "      vibevault-mcp   (MCP server for Claude Code, Cursor, etc.)"
echo "      vibevault       (CLI)"
