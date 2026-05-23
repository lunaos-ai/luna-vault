#!/usr/bin/env bash
set -euo pipefail

# Wrap the SwiftPM-built LunaVaultApp executable into a .app bundle so
# MenuBarExtra, Info.plist, and entitlements behave correctly.
# Output: build/LunaVault.app

cd "$(dirname "$0")/.."

CONFIG="${1:-debug}"   # debug | release
case "$CONFIG" in
    debug) SWIFT_BUILD_FLAGS="" ;;
    release) SWIFT_BUILD_FLAGS="-c release" ;;
    *) echo "usage: $0 [debug|release]"; exit 64 ;;
esac

echo "==> Building LunaVaultApp ($CONFIG)..."
swift build $SWIFT_BUILD_FLAGS --product LunaVaultApp

ARCH=$(uname -m)
BIN_DIR=".build/${ARCH}-apple-macosx/${CONFIG}"
BIN="$BIN_DIR/LunaVaultApp"

if [ ! -x "$BIN" ]; then
    echo "error: binary not found at $BIN"; exit 1
fi

APP_DIR="build/LunaVault.app"
echo "==> Bundling to $APP_DIR..."
rm -rf "$APP_DIR"
mkdir -p "$APP_DIR/Contents/MacOS" "$APP_DIR/Contents/Resources"

cp "$BIN" "$APP_DIR/Contents/MacOS/LunaVault"
cp apps/LunaVaultApp/Info.plist "$APP_DIR/Contents/Info.plist"

# Patch Info.plist so the binary name matches.
/usr/libexec/PlistBuddy -c "Set :CFBundleExecutable LunaVault" "$APP_DIR/Contents/Info.plist" 2>/dev/null || true

# Ad-hoc sign so MenuBarExtra/LAContext work without Developer ID.
codesign --force --deep --sign - "$APP_DIR" 2>&1 | sed 's/^/  codesign: /'

echo ""
echo "==> Done."
echo "    open $APP_DIR"
