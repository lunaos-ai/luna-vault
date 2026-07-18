#!/usr/bin/env bash
# Shared iCloud release paths for VibeVault DMG distribution.
set -euo pipefail

icloud_release_dir() {
    if [ -n "${ICLOUD_RELEASE_DIR:-}" ]; then
        printf '%s\n' "$ICLOUD_RELEASE_DIR"
        return
    fi
  local docs="$HOME/Library/Mobile Documents/com~apple~CloudDocs/Documents"
    if [ -d "$docs" ]; then
        printf '%s/VibeVault/Releases\n' "$docs"
    else
        printf '%s/VibeVault/Releases\n' "$HOME/Documents"
    fi
}

icloud_dmg_path() {
    printf '%s/%s\n' "$(icloud_release_dir)" "${DMG_NAME:-VibeVault}.dmg"
}
