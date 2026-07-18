#!/usr/bin/env bash
# Smoke test iCloud publish/fetch using a temp directory (no real iCloud needed).
set -euo pipefail

cd "$(dirname "$0")/../.."
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

fail() { echo "FAIL: $*"; exit 1; }
pass() { echo "PASS: $*"; }

export ICLOUD_RELEASE_DIR="$TMP/Releases"
DMG="build/VibeVault.dmg"

[ -f "$DMG" ] || bash scripts/create-dmg.sh >/dev/null
DMG_SRC="$DMG" bash scripts/publish-to-icloud.sh || fail "publish"
[ -f "$ICLOUD_RELEASE_DIR/VibeVault.dmg" ] || fail "published DMG missing"

export ICLOUD_RELEASE_DIR
bash scripts/fetch-from-icloud.sh || fail "fetch"
[ -f build/icloud-fetch/VibeVault.dmg ] || fail "local fetch copy missing"

pass "iCloud publish/fetch smoke test"
