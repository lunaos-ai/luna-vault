#!/usr/bin/env bash
# Notarize a DMG and staple the ticket. Requires same env vars as notarize.sh.
set -euo pipefail

: "${NOTARYTOOL_APPLE_ID:?missing}"
: "${NOTARYTOOL_TEAM_ID:?missing}"
: "${NOTARYTOOL_PASSWORD:?missing}"
DMG_PATH="${DMG_PATH:-build/VibeVault.dmg}"

xcrun notarytool submit "$DMG_PATH" \
    --apple-id "$NOTARYTOOL_APPLE_ID" \
    --team-id "$NOTARYTOOL_TEAM_ID" \
    --password "$NOTARYTOOL_PASSWORD" \
    --wait

xcrun stapler staple "$DMG_PATH"
xcrun stapler validate "$DMG_PATH"
echo "notarized + stapled: $DMG_PATH"
