#!/usr/bin/env bash
# Builds Install Vibe Vault.app — one-click DMG installer with progress UI.
set -euo pipefail

cd "$(dirname "$0")/../.."
OUT="build/dmg-resources/Install Vibe Vault.app"
BIN_DIR="build/dmg-resources/bin"
HELPER="$BIN_DIR/install-helper"

rm -rf "$OUT" "$BIN_DIR"
mkdir -p "$OUT/Contents/MacOS" "$OUT/Contents/Resources" "$BIN_DIR"

echo "==> Compiling install helper..."
swiftc -O -parse-as-library \
    -framework AppKit -framework Foundation \
    -o "$HELPER" \
    scripts/dmg/InstallHelper.swift

cat > "$OUT/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
 "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>CFBundleExecutable</key><string>install</string>
  <key>CFBundleIdentifier</key><string>dev.vibevault.installer</string>
  <key>CFBundleName</key><string>Install Vibe Vault</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>0.1.0</string>
  <key>CFBundleVersion</key><string>1</string>
  <key>LSMinimumSystemVersion</key><string>14.0</string>
  <key>NSHighResolutionCapable</key><true/>
</dict></plist>
PLIST

cp "$HELPER" "$OUT/Contents/MacOS/install"
ICON="apps/VibeVaultApp/Resources/AppIcon.icns"
if [ -f "$ICON" ]; then
    cp "$ICON" "$OUT/Contents/Resources/AppIcon.icns"
    /usr/libexec/PlistBuddy -c "Add :CFBundleIconFile string AppIcon" \
        "$OUT/Contents/Info.plist" 2>/dev/null || true
fi

codesign --force --sign - "$OUT/Contents/MacOS/install" 2>/dev/null || true
codesign --force --sign - "$OUT" 2>/dev/null || true
echo "==> $OUT"
