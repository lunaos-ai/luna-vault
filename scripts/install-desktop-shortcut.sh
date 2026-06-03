#!/usr/bin/env bash
# Installs a Finder alias for VibeVault.app on ~/Desktop.
# Idempotent: replaces any existing alias of the same name.
set -eo pipefail

cd "$(dirname "$0")/.."

APP_PATH="$(pwd)/build/VibeVault.app"
if [ ! -d "$APP_PATH" ]; then
    echo "error: $APP_PATH not found. Run ./scripts/bundle-app.sh first."
    exit 1
fi

DESKTOP="$HOME/Desktop"
ALIAS_NAME="Vibe Vault"
ALIAS_PATH="$DESKTOP/$ALIAS_NAME"

# Remove old alias if it exists (Finder alias OR symlink).
if [ -e "$ALIAS_PATH" ] || [ -L "$ALIAS_PATH" ]; then
    rm -f "$ALIAS_PATH"
fi

# Use AppleScript so Finder makes a real macOS alias (preserves icon, survives
# moves of the target, shows up correctly in LaunchServices). A symlink does
# not — Finder draws it with a generic icon.
/usr/bin/osascript <<APPLESCRIPT
tell application "Finder"
    set targetApp to POSIX file "$APP_PATH" as alias
    set desktopFolder to POSIX file "$DESKTOP" as alias
    set newAlias to make new alias file at desktopFolder to targetApp
    set name of newAlias to "$ALIAS_NAME"
end tell
APPLESCRIPT

echo "==> Alias placed at: $ALIAS_PATH"
echo "    Target:          $APP_PATH"
echo ""
echo "    Double-click \"$ALIAS_NAME\" on your Desktop to launch."
