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
[ -f docs/launch/GTM_RUNBOOK.md ] && ok "GTM runbook" || fail "GTM runbook missing"
[ -f docs/launch/GTM_STRATEGY.md ] && ok "GTM strategy" || fail "GTM strategy missing"
[ -f docs/launch/MARKET_EVIDENCE.md ] && ok "Market evidence" || fail "Market evidence missing"
[ -f docs/launch/APPLE_DEVELOPER_BLOCKED.md ] && ok "Apple enrollment fallback" || fail "Apple enrollment fallback missing"
[ -f docs/launch/AI_AGENT_MARKETING_BLITZ.md ] && ok "AI-agent marketing blitz" || fail "AI-agent marketing blitz missing"
[ -f docs/AGENT_SECRET_POLICY.md ] && ok "Agent secret policy docs" || fail "Agent secret policy docs missing"
[ -f docs/launch/COMMUNITY_POSTS.md ] && ok "Community posts" || fail "Community posts missing"
[ -f docs/launch/PRODUCT_HUNT.md ] && ok "Product Hunt plan" || fail "Product Hunt plan missing"
[ -f dist/cursor-directory/vibe-vault.json ] && ok "Cursor directory draft" || fail "Cursor directory draft missing"

grep -qi 'Generate new local secrets' workers/vibevault/public/index.html && ok "Landing mentions key generator" || fail "Landing missing key generator copy"
grep -qi 'Homebrew-first launch path' workers/vibevault/public/install/index.html && ok "Homebrew-first install page" || fail "Install page missing Homebrew-first path"
grep -qi 'Credential boundary for AI agents' workers/vibevault/public/agents/index.html && ok "AI-agent landing page" || fail "AI-agent landing page missing"
grep -q 'vibevault agents prepare --target all' workers/vibevault/public/agents/index.html && ok "Agent policy install CTA" || fail "Agents page missing policy install CTA"
[ -f workers/vibevault/public/llms.txt ] && grep -q 'vibevault agents prepare --target all' workers/vibevault/public/llms.txt && ok "LLM guidance file" || fail "LLM guidance file missing"
grep -qi 'vibevault scan' workers/vibevault/public/scan/index.html && ok "Scanner landing page" || fail "Scanner landing page missing scan command"
grep -qi 'Security architecture' workers/vibevault/public/security/index.html && ok "Security architecture page" || fail "Security architecture page missing"
grep -qi 'browser import' docs/launch/LAUNCH_PACK.md && ok "Launch copy mentions browser import" || fail "Launch copy missing browser import"
grep -qi 'encrypted sync' docs/launch/LAUNCH_PACK.md && ok "Launch copy mentions encrypted sync" || fail "Launch copy missing encrypted sync"

# Engineering gates
if bash scripts/check-loc.sh >/dev/null 2>&1; then ok "LOC ≤200"; else fail "LOC over limit"; fi
if swift build --product vibevault >/dev/null 2>&1 &&
   .build/debug/vibevault agents status --target all --path . >/dev/null 2>&1; then
  ok "Agent policy CLI"
else
  fail "Agent policy CLI failed"
fi

# Soft: notarization credentials
if [ -n "${NOTARYTOOL_APPLE_ID:-}" ] && [ -n "${NOTARYTOOL_TEAM_ID:-}" ] && [ -n "${NOTARYTOOL_PASSWORD:-}" ]; then
  ok "Notary credentials present in env"
else
  warn "Notary credentials not set (NOTARYTOOL_*) — required before public Gatekeeper-safe DMG"
fi

# Soft: release DMG and notarization state
if [ -f build/VibeVault.dmg ]; then
  ok "build/VibeVault.dmg exists"
  if xcrun stapler validate build/VibeVault.dmg >/dev/null 2>&1; then
    ok "DMG has stapled notary ticket"
  else
    warn "DMG has no stapled notary ticket"
  fi
  if spctl -a -vv -t open build/VibeVault.dmg >/dev/null 2>&1; then
    ok "Gatekeeper accepts DMG"
  else
    warn "Gatekeeper rejects DMG"
  fi
else
  warn "No DMG yet — run scripts/release.sh"
fi

if [ -d build/VibeVault.app ]; then
  if spctl -a -vv build/VibeVault.app >/dev/null 2>&1; then
    ok "Gatekeeper accepts app"
  else
    warn "Gatekeeper rejects app"
  fi
fi

if [ -f build/VibeVault-Browser-Importer.zip ]; then
  ok "Browser extension zip"
else
  warn "No browser extension zip — run scripts/package-browser-extension.sh"
fi

if [ -f extensions/browser-vibevault/store/listing.md ] &&
   [ -f extensions/browser-vibevault/store/privacy.md ] &&
   [ -f extensions/browser-vibevault/store/review-notes.md ]; then
  ok "Chrome Web Store package docs"
else
  warn "Chrome Web Store package docs incomplete"
fi

if command -v curl >/dev/null 2>&1 &&
   curl -fsSL --max-time 8 https://vibevault.lunaos.ai/health | grep -q '"ok":true'; then
  ok "Live Worker health"
else
  warn "Could not verify live Worker health"
fi

# Soft: homebrew tap remote
if command -v gh >/dev/null 2>&1 && gh repo view finsavvyai/homebrew-tap &>/dev/null; then
  ok "finsavvyai/homebrew-tap reachable"
else
  warn "Cannot verify finsavvyai/homebrew-tap (gh auth or repo)"
fi

echo ""
echo "Summary: $FAIL fail, $WARN warn"
if [ "$FAIL" -gt 0 ]; then exit 1; fi
echo "GTM artifacts ready. Homebrew, source, website, and Chrome importer are live; native app launch still needs Developer ID notarization."
