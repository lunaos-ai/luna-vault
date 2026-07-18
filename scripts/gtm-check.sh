#!/usr/bin/env bash
# GTM readiness check — exits 1 if hard requirements fail.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
FAIL=0
WARN=0

ok()   { echo "  OK  $*"; }
warn() { echo "  WARN $*"; WARN=$((WARN + 1)); }
fail() { echo "  FAIL $*"; FAIL=$((FAIL + 1)); }

echo "==> GTM check (vibe-vault)"

# Hard: release artifacts in repo
[ -f LICENSE ] && ok "LICENSE" || fail "LICENSE missing"
[ -f CHANGELOG.md ] && ok "CHANGELOG.md" || fail "CHANGELOG.md missing"
grep -q '0\.1\.0' cli/vibevault/VibeVault.swift && ok "CLI version 0.1.0" || fail "CLI version not 0.1.0"
[ -f dist/homebrew/vibevault.rb ] && ok "Homebrew formula" || fail "Homebrew formula missing"
[ -f marketing/landing/index.html ] && ok "Landing page" || fail "Landing page missing"
[ -f docs/launch/LAUNCH_PACK.md ] && ok "Launch pack" || fail "Launch pack missing"
[ -f dist/cursor-directory/vibe-vault.json ] && ok "Cursor directory draft" || fail "Cursor directory draft missing"

# Engineering gates
if bash scripts/check-loc.sh >/dev/null 2>&1; then ok "LOC ≤200"; else fail "LOC over limit"; fi

# Soft: notarization credentials
if [ -n "${NOTARYTOOL_APPLE_ID:-}" ] && [ -n "${NOTARYTOOL_TEAM_ID:-}" ] && [ -n "${NOTARYTOOL_PASSWORD:-}" ]; then
  ok "Notary credentials present in env"
else
  warn "Notary credentials not set (NOTARYTOOL_*) — required before public Gatekeeper-safe DMG"
fi

# Soft: release DMG
if [ -f build/VibeVault.dmg ]; then ok "build/VibeVault.dmg exists"; else warn "No DMG yet — run scripts/release.sh"; fi

# Soft: homebrew tap remote
if command -v gh >/dev/null 2>&1 && gh repo view luna-os/homebrew-tap &>/dev/null; then
  ok "luna-os/homebrew-tap reachable"
else
  warn "Cannot verify luna-os/homebrew-tap (gh auth or repo)"
fi

echo ""
echo "Summary: $FAIL fail, $WARN warn"
if [ "$FAIL" -gt 0 ]; then exit 1; fi
echo "GTM artifacts ready. Remaining: notarize → publish DMG → push brew formula → post LAUNCH_PACK."
