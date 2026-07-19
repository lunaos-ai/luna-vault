#!/usr/bin/env bash
# Build a clean Chrome Web Store upload zip for Vibe Vault Importer.
set -euo pipefail

cd "$(dirname "$0")/.."

SRC="${BROWSER_EXTENSION_DIR:-extensions/browser-vibevault}"
ZIP="${BROWSER_EXTENSION_ZIP:-build/VibeVault-Browser-Importer.zip}"
STAGE="build/browser-extension-upload"
ROOT_NAME="browser-vibevault"

rm -rf "$STAGE"
mkdir -p "$STAGE/$ROOT_NAME"
cp -f "$SRC/manifest.json" "$STAGE/$ROOT_NAME/manifest.json"
cp -f "$SRC/README.md" "$STAGE/$ROOT_NAME/README.md"
cp -R "$SRC/src" "$STAGE/$ROOT_NAME/src"
cp -R "$SRC/assets" "$STAGE/$ROOT_NAME/assets"

mkdir -p "$(dirname "$ZIP")"
rm -f "$ZIP"
ditto -c -k --norsrc --keepParent "$STAGE/$ROOT_NAME" "$ZIP"

echo "packaged $ZIP ($(du -h "$ZIP" | awk '{print $1}'))"
