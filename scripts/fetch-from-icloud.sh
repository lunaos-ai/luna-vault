#!/usr/bin/env bash
# Fetch VibeVault.dmg from iCloud Drive and optionally install to Applications.
set -euo pipefail

cd "$(dirname "$0")/.."
source scripts/dmg/icloud-path.sh

INSTALL=0
for arg in "$@"; do
    case "$arg" in
        --install|-i) INSTALL=1 ;;
        --help|-h)
            echo "usage: $0 [--install]"
            echo "  Fetches $(icloud_dmg_path) from iCloud Drive."
            echo "  --install  Mount DMG and install VibeVault to /Applications."
            exit 0
            ;;
    esac
done

SRC="$(icloud_dmg_path)"
DEST_DIR="build/icloud-fetch"
LOCAL="$DEST_DIR/$(basename "$SRC")"

if [ ! -e "$SRC" ]; then
    echo "error: not in iCloud yet: $SRC"
    echo "       publish first: bash scripts/publish-to-icloud.sh"
    exit 1
fi

mkdir -p "$DEST_DIR"
echo "==> Fetching from iCloud..."
echo "    $SRC"

wait_for_download() {
    local path="$1"
    local max="${2:-180}"
    local elapsed=0
    while [ "$elapsed" -lt "$max" ]; do
        if [ -f "$path" ] && [ "$(stat -f%z "$path" 2>/dev/null || echo 0)" -gt 100000 ]; then
            return 0
        fi
        # Reading triggers iCloud materialization on cloud-only files.
        dd if="$path" of=/dev/null bs=1 count=1 2>/dev/null || true
        sleep 2
        elapsed=$((elapsed + 2))
        echo "    waiting for iCloud download (${elapsed}s)..."
    done
    return 1
}

wait_for_download "$SRC" || {
    echo "error: timed out waiting for iCloud download"
    exit 1
}

cp -f "$SRC" "$LOCAL"
echo "==> Local copy: $LOCAL ($(du -h "$LOCAL" | awk '{print $1}'))"

if [ "$INSTALL" -ne 1 ]; then
    echo "    open \"$LOCAL\""
    exit 0
fi

echo "==> Installing from DMG..."
MOUNT_OUT=$(hdiutil attach -readonly -noverify -noautoopen "$LOCAL")
MOUNT=$(echo "$MOUNT_OUT" | grep -o '/Volumes/.*' | head -1)
trap 'hdiutil detach "$MOUNT" -quiet 2>/dev/null || true' EXIT

APP_SRC="$MOUNT/VibeVault.app"
INSTALLER="$MOUNT/Install Vibe Vault.app"
DEST_APP="/Applications/VibeVault.app"

if [ -d "$INSTALLER" ]; then
    echo "==> Running one-click installer..."
    open -W "$INSTALLER"
elif [ -d "$APP_SRC" ]; then
    echo "==> Copying VibeVault.app to Applications..."
    rm -rf "$DEST_APP"
    ditto "$APP_SRC" "$DEST_APP"
    echo "==> Installed: $DEST_APP"
else
    echo "error: DMG missing VibeVault.app"
    exit 1
fi

hdiutil detach "$MOUNT" -quiet
trap - EXIT
echo "==> Done."
