#!/usr/bin/env bash
set -euo pipefail

# Notarize the built .app and stapler. Requires:
#   NOTARYTOOL_APPLE_ID       Apple ID email
#   NOTARYTOOL_TEAM_ID        Developer team identifier
#   NOTARYTOOL_PASSWORD       App-specific password
#   APP_PATH                  Path to VibeVault.app

: "${NOTARYTOOL_APPLE_ID:?missing}"
: "${NOTARYTOOL_TEAM_ID:?missing}"
: "${NOTARYTOOL_PASSWORD:?missing}"
APP_PATH="${APP_PATH:-build/VibeVault.app}"

ZIP="${APP_PATH%.app}.zip"
ditto -c -k --keepParent "$APP_PATH" "$ZIP"

xcrun notarytool submit "$ZIP" \
    --apple-id "$NOTARYTOOL_APPLE_ID" \
    --team-id "$NOTARYTOOL_TEAM_ID" \
    --password "$NOTARYTOOL_PASSWORD" \
    --wait

xcrun stapler staple "$APP_PATH"
xcrun stapler validate "$APP_PATH"
echo "notarized + stapled: $APP_PATH"
