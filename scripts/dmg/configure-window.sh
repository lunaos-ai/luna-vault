#!/usr/bin/env bash
# Configures Finder window layout on a mounted DMG volume.
set -euo pipefail

VOLUME_PATH="${1:?volume path}"
BACKGROUND="${2:?background png path}"
VOL_NAME="$(basename "$VOLUME_PATH")"

mkdir -p "$VOLUME_PATH/.background"
cp "$BACKGROUND" "$VOLUME_PATH/.background/background.png"
SetFile -a V "$VOLUME_PATH/.background" 2>/dev/null || chflags hidden "$VOLUME_PATH/.background"

/usr/bin/osascript <<APPLESCRIPT || echo "warning: Finder window layout skipped"
tell application "Finder"
    tell disk "$VOL_NAME"
        open
        set current view of container window to icon view
        set toolbar visible of container window to false
        set statusbar visible of container window to false
        set bounds of container window to {200, 120, 860, 520}
        set theViewOptions to icon view options of container window
        set arrangement of theViewOptions to not arranged
        set icon size of theViewOptions to 96
        set background picture of theViewOptions to file ".background:background.png"
        set position of item "VibeVault.app" of container window to {140, 180}
        set position of item "Applications" of container window to {460, 180}
        try
            set position of item "Install Vibe Vault.app" of container window to {300, 320}
        end try
        close
        open
        update without registering applications
        delay 1
    end tell
end tell
APPLESCRIPT
