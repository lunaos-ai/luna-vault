#!/usr/bin/env bash
# Smoke test: bundle app, create DMG, verify mountable contents.
set -euo pipefail

cd "$(dirname "$0")/../.."
ROOT="$(pwd)"

fail() { echo "FAIL: $*"; exit 1; }
pass() { echo "PASS: $*"; }

echo "==> DMG smoke test"

bash scripts/bundle-app.sh release || fail "bundle-app.sh"
[ -d build/VibeVault.app ] || fail "VibeVault.app missing"

bash scripts/create-dmg.sh || fail "create-dmg.sh"
[ -f build/VibeVault.dmg ] || fail "VibeVault.dmg missing"

MOUNT_OUT=$(hdiutil attach -readonly -noverify build/VibeVault.dmg)
MOUNT=$(echo "$MOUNT_OUT" | grep -o '/Volumes/.*' | head -1)
trap 'hdiutil detach "$MOUNT" -quiet 2>/dev/null || true' EXIT

[ -d "$MOUNT/VibeVault.app" ] || fail "DMG missing VibeVault.app"
[ -L "$MOUNT/Applications" ] || fail "DMG missing Applications symlink"
[ -d "$MOUNT/Install Vibe Vault.app" ] || fail "DMG missing installer app"
[ "$(readlink "$MOUNT/Applications")" = "/Applications" ] || fail "bad Applications link"

SIZE_MB=$(du -m build/VibeVault.dmg | awk '{print $1}')
echo "DMG size: ${SIZE_MB} MB"
[ "$SIZE_MB" -lt 50 ] || fail "DMG unexpectedly large (${SIZE_MB} MB)"

hdiutil detach "$MOUNT" -quiet
trap - EXIT

pass "DMG smoke test complete"
