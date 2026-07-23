#!/usr/bin/env bash
# Build a clean Chrome Web Store upload zip for Vibe Vault Importer.
set -euo pipefail

cd "$(dirname "$0")/.."

SRC="${BROWSER_EXTENSION_DIR:-extensions/browser-vibevault}"
ZIP="${BROWSER_EXTENSION_ZIP:-build/VibeVault-Browser-Importer.zip}"
STAGE="build/browser-extension-upload"
ZIP_DIR="$(dirname "$ZIP")"
mkdir -p "$ZIP_DIR"
ZIP_ABS="$(cd "$ZIP_DIR" && pwd)/$(basename "$ZIP")"

rm -rf "$STAGE"
mkdir -p "$STAGE"
cp -f "$SRC/manifest.json" "$STAGE/manifest.json"
cp -f "$SRC/README.md" "$STAGE/README.md"
cp -R "$SRC/src" "$STAGE/src"
cp -R "$SRC/assets" "$STAGE/assets"

rm -f "$ZIP_ABS"
(cd "$STAGE" && zip -qr "$ZIP_ABS" manifest.json README.md src assets)

echo "packaged $ZIP ($(du -h "$ZIP" | awk '{print $1}'))"
