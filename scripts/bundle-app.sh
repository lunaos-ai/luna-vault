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

# Signing identity selection:
#   - For distribution, export DEVELOPER_ID="Developer ID Application: Name (TEAMID)".
#     The build is then signed with the hardened runtime + secure timestamp so it
#     can be notarized by Apple.
#   - Otherwise prefer the stable self-signed dev identity ("VibeVault Dev") so
#     Keychain "Always Allow" persists across rebuilds.
#   - Otherwise fall back to ad-hoc (Keychain re-prompts every rebuild).
EXTRA_OPTS=()
if [ -n "${DEVELOPER_ID:-}" ]; then
  SIGN_ID="$DEVELOPER_ID"
  EXTRA_OPTS=(--options runtime --timestamp)
  echo "==> Signing for distribution with \"$SIGN_ID\" (hardened runtime + timestamp)."
elif security find-identity -p codesigning ~/Library/Keychains/login.keychain-db 2>/dev/null \
   | grep -q "VibeVault Dev"; then
  SIGN_ID="VibeVault Dev"
  echo "==> Signing with stable dev identity \"$SIGN_ID\"."
else
  SIGN_ID="-"
  echo "==> No identity found. Using ad-hoc (Keychain prompt every rebuild)."
  echo "    Run: scripts/dev-codesign-setup.sh  (dev)  or set DEVELOPER_ID (release)."
fi

# Pin stable bundle identifiers. Without --identifier, codesign derives one from
# the binary's content hash (e.g. vibevault-mcp-5555...), which changes every
# build and breaks the Keychain ACL match — so "Always Allow" never sticks.
# Inner binaries are signed before the outer bundle (required for a valid seal).
sign() { codesign --force --sign "$SIGN_ID" "${EXTRA_OPTS[@]}" "$@" 2>&1 | sed 's/^/  codesign: /'; }
sign --identifier dev.vibevault.cli --entitlements "$ENT_CLI" "$APP_DIR/Contents/Helpers/vibevault"
sign --identifier dev.vibevault.mcp --entitlements "$ENT_MCP" "$APP_DIR/Contents/MacOS/vibevault-mcp"
sign --identifier dev.vibevault     --entitlements "$ENT_APP" "$APP_DIR/Contents/MacOS/VibeVault"
sign --identifier dev.vibevault     --entitlements "$ENT_APP" "$APP_DIR"

codesign --verify --deep --strict --verbose=1 "$APP_DIR" 2>&1 | sed 's/^/  verify: /' || true

# Package a compressed DMG with an /Applications drop target.
VERSION=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$APP_DIR/Contents/Info.plist" 2>/dev/null || echo "0.0.0")
DMG="build/VibeVault-${VERSION}.dmg"
echo "==> Building $DMG..."
STAGE=$(mktemp -d); cp -R "$APP_DIR" "$STAGE/"; ln -s /Applications "$STAGE/Applications"
rm -f "$DMG"
hdiutil create -volname "Vibe Vault" -srcfolder "$STAGE" -ov -format UDZO "$DMG" >/dev/null
rm -rf "$STAGE"

# Notarize + staple when distribution credentials are present. Provide EITHER a
# stored keychain profile (NOTARY_PROFILE, from `xcrun notarytool store-credentials`)
# OR APPLE_ID + TEAM_ID + APP_PASSWORD (an app-specific password).
notarize() {
  if [ -n "${NOTARY_PROFILE:-}" ]; then
    xcrun notarytool submit "$DMG" --keychain-profile "$NOTARY_PROFILE" --wait
  elif [ -n "${APPLE_ID:-}" ] && [ -n "${TEAM_ID:-}" ] && [ -n "${APP_PASSWORD:-}" ]; then
    xcrun notarytool submit "$DMG" --apple-id "$APPLE_ID" --team-id "$TEAM_ID" \
      --password "$APP_PASSWORD" --wait
  else
    return 2
  fi
}
if [ -n "${DEVELOPER_ID:-}" ]; then
  echo "==> Submitting for notarization..."
  if notarize; then
    xcrun stapler staple "$APP_DIR" && xcrun stapler staple "$DMG"
    echo "==> Notarized and stapled."
  else
    echo "==> Skipped notarization (set NOTARY_PROFILE, or APPLE_ID+TEAM_ID+APP_PASSWORD)."
  fi
fi

echo ""
echo "==> Done."
echo "    open $APP_DIR"
echo "    $DMG"
echo ""
echo "    Bundled binaries:"
echo "      VibeVault       (app)"
echo "      vibevault-mcp   (MCP server for Claude Code, Cursor, etc.)"
echo "      vibevault       (CLI)"
