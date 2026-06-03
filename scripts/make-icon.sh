#!/usr/bin/env bash
# Renders apps/VibeVaultApp/Resources/AppIcon.icns from scripts/IconGen.swift.
set -eo pipefail

cd "$(dirname "$0")/.."
OUT_DIR="apps/VibeVaultApp/Resources"
TMP_ROOT="$(mktemp -d)"
ICONSET="$TMP_ROOT/AppIcon.iconset"
mkdir -p "$OUT_DIR" "$ICONSET"

render() {
    local size="$1"
    local name="$2"
    echo "==> $name (${size}x${size})"
    swift scripts/IconGen.swift "$ICONSET/$name" "$size"
}

render 16   icon_16x16.png
render 32   icon_16x16@2x.png
render 32   icon_32x32.png
render 64   icon_32x32@2x.png
render 128  icon_128x128.png
render 256  icon_128x128@2x.png
render 256  icon_256x256.png
render 512  icon_256x256@2x.png
render 512  icon_512x512.png
render 1024 icon_512x512@2x.png

iconutil --convert icns --output "$OUT_DIR/AppIcon.icns" "$ICONSET"
rm -rf "$TMP_ROOT"
echo ""
echo "wrote $OUT_DIR/AppIcon.icns"
