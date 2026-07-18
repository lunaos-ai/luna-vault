#!/usr/bin/env bash
# Full release pipeline: bundle .app → DMG → optional notarize.
set -euo pipefail

cd "$(dirname "$0")/.."

CONFIG="${1:-release}"
NOTARIZE="${NOTARIZE:-0}"

echo "==> [1/3] Bundling VibeVault.app ($CONFIG)..."
bash scripts/bundle-app.sh "$CONFIG"

echo "==> [2/3] Creating DMG..."
bash scripts/create-dmg.sh

if [ "$NOTARIZE" = "1" ]; then
    echo "==> [3/3] Notarizing app (set NOTARIZE_DMG=1 to also notarize DMG)..."
    bash scripts/notarize.sh
    if [ "${NOTARIZE_DMG:-0}" = "1" ]; then
        bash scripts/notarize-dmg.sh
    fi
else
    echo "==> [3/3] Skipping notarization (set NOTARIZE=1 to enable)"
fi

echo ""
echo "Release artifacts:"
echo "  build/VibeVault.app"
echo "  build/VibeVault.dmg"

if [ "${PUBLISH_ICLOUD:-0}" = "1" ]; then
    echo ""
    bash scripts/publish-to-icloud.sh
fi

if [ "${PUBLISH_WEBSITE:-0}" = "1" ]; then
    echo ""
    bash scripts/publish-to-website.sh
fi
