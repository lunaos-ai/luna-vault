#!/usr/bin/env bash
# Creates a distributable VibeVault.dmg with drag-to-Applications layout
# and a one-click installer with progress UI.
set -euo pipefail

cd "$(dirname "$0")/.."

APP_PATH="${APP_PATH:-build/VibeVault.app}"
DMG_NAME="${DMG_NAME:-VibeVault}"
OUTPUT="${OUTPUT:-build/${DMG_NAME}.dmg}"
VOLUME_NAME="Vibe Vault"
STAGING="build/dmg-staging"
RW_DMG="build/${DMG_NAME}-rw.dmg"

if [ ! -d "$APP_PATH" ]; then
    echo "error: $APP_PATH not found — run scripts/bundle-app.sh release first"
    exit 1
fi

echo "==> Preparing DMG resources..."
bash scripts/dmg/build-installer-app.sh
mkdir -p build/dmg-resources
BG="build/dmg-resources/background.png"
swift scripts/dmg/DMGBackgroundGen.swift "$BG" 660 400

echo "==> Staging DMG contents..."
rm -rf "$STAGING" "$RW_DMG" "$OUTPUT"
mkdir -p "$STAGING"
cp -R "$APP_PATH" "$STAGING/"
cp -R "build/dmg-resources/Install Vibe Vault.app" "$STAGING/"
ln -s /Applications "$STAGING/Applications"

APP_KB=$(du -sk "$STAGING" | awk '{print $1}')
DMG_MB=$(( APP_KB / 1024 + 8 ))
echo "==> Creating ${DMG_MB}M read-write image..."
hdiutil create -size "${DMG_MB}m" -fs HFS+ -volname "$VOLUME_NAME" -ov "$RW_DMG" >/dev/null

MOUNT_OUT=$(hdiutil attach -readwrite -noverify -noautoopen "$RW_DMG")
MOUNT_POINT="/Volumes/$VOLUME_NAME"
if [ ! -d "$MOUNT_POINT" ]; then
    MOUNT_POINT=$(echo "$MOUNT_OUT" | grep -o '/Volumes/.*' | head -1)
fi
trap 'hdiutil detach "$MOUNT_POINT" -quiet 2>/dev/null || true' EXIT

echo "==> Copying to $MOUNT_POINT..."
ditto "$STAGING/" "$MOUNT_POINT/"
bash scripts/dmg/configure-window.sh "$MOUNT_POINT" "$BG"

echo "==> Finalizing compressed DMG..."
hdiutil detach "$MOUNT_POINT" -quiet
trap - EXIT
hdiutil convert "$RW_DMG" -format UDZO -imagekey zlib-level=9 -o "$OUTPUT" >/dev/null
rm -f "$RW_DMG"

SIZE_MB=$(du -m "$OUTPUT" | awk '{print $1}')
echo ""
echo "==> Done: $OUTPUT (${SIZE_MB} MB)"
if [ "$SIZE_MB" -gt 20 ]; then
    echo "warning: DMG exceeds 20 MB release target"
fi
echo "    open \"$OUTPUT\""
