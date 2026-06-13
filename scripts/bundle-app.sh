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

# App icon — generate if missing, then copy into Resources.
ICON_SRC="apps/VibeVaultApp/Resources/AppIcon.icns"
if [ ! -f "$ICON_SRC" ]; then
    echo "==> AppIcon.icns missing — generating…"
    bash scripts/make-icon.sh
fi
cp "$ICON_SRC" "$APP_DIR/Contents/Resources/AppIcon.icns"

/usr/libexec/PlistBuddy -c "Set :CFBundleExecutable VibeVault" "$APP_DIR/Contents/Info.plist" 2>/dev/null || true

# Sign each binary with its own entitlements for shared Keychain access group.
ENT_APP="apps/VibeVaultApp/VibeVault.entitlements"
ENT_CLI="cli/vibevault/vibevault.entitlements"
ENT_MCP="cli/vibevault-mcp/vibevault-mcp.entitlements"

# Prefer a stable self-signed dev identity so Keychain "Always Allow" persists
# across rebuilds. Falls back to ad-hoc if the identity isn't installed.
SIGN_ID="-"
if security find-identity -p codesigning ~/Library/Keychains/login.keychain-db 2>/dev/null \
   | grep -q "VibeVault Dev"; then
  SIGN_ID="VibeVault Dev"
  echo "==> Signing with stable identity \"$SIGN_ID\"."
else
  echo "==> No stable identity found. Using ad-hoc (Keychain prompt every rebuild)."
  echo "    Run: scripts/dev-codesign-setup.sh"
fi

# Pin stable bundle identifiers. Without --identifier, codesign derives one from
# the binary's content hash (e.g. vibevault-mcp-5555...), which changes every
# build and breaks the Keychain ACL match — so "Always Allow" never sticks.
codesign --force --sign "$SIGN_ID" --identifier dev.vibevault.cli --entitlements "$ENT_CLI" "$APP_DIR/Contents/Helpers/vibevault" 2>&1 | sed 's/^/  codesign: /'
codesign --force --sign "$SIGN_ID" --identifier dev.vibevault.mcp --entitlements "$ENT_MCP" "$APP_DIR/Contents/MacOS/vibevault-mcp" 2>&1 | sed 's/^/  codesign: /'
codesign --force --sign "$SIGN_ID" --identifier dev.vibevault --entitlements "$ENT_APP" "$APP_DIR/Contents/MacOS/VibeVault" 2>&1 | sed 's/^/  codesign: /'
codesign --force --sign "$SIGN_ID" --identifier dev.vibevault --entitlements "$ENT_APP" "$APP_DIR" 2>&1 | sed 's/^/  codesign: /'

echo ""
echo "==> Done."
echo "    open $APP_DIR"
echo ""
echo "    Bundled binaries:"
echo "      VibeVault       (app)"
echo "      vibevault-mcp   (MCP server for Claude Code, Cursor, etc.)"
echo "      vibevault       (CLI)"
