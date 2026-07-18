#!/usr/bin/env bash
# Copy build/VibeVault.dmg into iCloud Drive for cross-Mac distribution.
set -euo pipefail

cd "$(dirname "$0")/.."
source scripts/dmg/icloud-path.sh

DMG_SRC="${DMG_SRC:-build/VibeVault.dmg}"
DEST_DIR="$(icloud_release_dir)"
DEST="$(icloud_dmg_path)"

if [ ! -f "$DMG_SRC" ]; then
    echo "error: $DMG_SRC not found — run scripts/release.sh first"
    exit 1
fi

mkdir -p "$DEST_DIR"
echo "==> Publishing to iCloud: $DEST"
cp -f "$DMG_SRC" "$DEST"

# Trigger iCloud upload sync.
touch "$DEST"
brctl monitor -t 5 com.apple.CloudDocs >/dev/null 2>&1 || true

echo "==> Published ($(du -h "$DEST" | awk '{print $1}'))"
echo "    Install on another Mac: bash scripts/fetch-from-icloud.sh --install"
