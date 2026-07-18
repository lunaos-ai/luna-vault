#!/usr/bin/env bash
# Setup-flows verification (no Accessibility — osascript often lacks assistive access).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"

PASS=0
FAIL=0
SKIP=0
note() { printf '%s\n' "$1"; }
pass() { note "PASS $1"; PASS=$((PASS + 1)); }
fail() { note "FAIL $1"; FAIL=$((FAIL + 1)); }
skip() { note "SKIP $1"; SKIP=$((SKIP + 1)); }

echo "==> Bundle debug app"
bash scripts/bundle-app.sh debug >/tmp/vv-setup-bundle.log 2>&1 || {
  fail "bundle-app"; tail -20 /tmp/vv-setup-bundle.log; exit 1
}
pass "bundle-app"

CLI="$ROOT/build/VibeVault.app/Contents/Helpers/vibevault"
MCP="$ROOT/build/VibeVault.app/Contents/MacOS/vibevault-mcp"
[[ -x "$CLI" ]] && pass "cli binary" || fail "cli binary missing"
[[ -x "$MCP" ]] && pass "mcp binary" || fail "mcp binary missing"

echo "==> Unit tests (setup-related)"
if swift test --filter 'ProviderCredentialStoreTests|MCPClientInstallerTests|MCPBinaryResolverTests|CursorProjectPrepTests|CloudflareProviderTests|LicenseCodecTests|BiometricGateTests' >/tmp/vv-setup-unit.log 2>&1; then
  pass "unit tests (see /tmp/vv-setup-unit.log)"
else
  fail "unit tests"
  tail -30 /tmp/vv-setup-unit.log
fi

echo "==> CLI setup surfaces"
if "$CLI" mcp status >/tmp/vv-mcp-status.log 2>&1; then
  pass "mcp status"
else
  fail "mcp status"
fi

if "$CLI" mcp test >/tmp/vv-mcp-test.log 2>&1; then
  pass "mcp test: $(head -1 /tmp/vv-mcp-test.log)"
else
  fail "mcp test: $(cat /tmp/vv-mcp-test.log)"
fi

if "$CLI" skill status >/tmp/vv-skill.log 2>&1; then
  pass "skill status"
else
  fail "skill status"
fi

TMP=$(mktemp -d /tmp/vv-setup-XXXX)
mkdir -p "$TMP/.git"
printf 'name = "test-worker"\naccount_id = "acct"\n' >"$TMP/wrangler.toml"
if "$CLI" cursor prepare --path "$TMP" >/tmp/vv-prepare.log 2>&1; then
  if [[ -f "$TMP/.cursor/rules/vibevault.mdc" ]] || [[ -d "$TMP/.cursor/rules" ]]; then
    pass "cursor prepare"
  else
    fail "cursor prepare missing .cursor/rules"
  fi
else
  fail "cursor prepare: $(tail -5 /tmp/vv-prepare.log)"
fi

echo "==> Static wiring (Setup chips → sheets / deep links)"
wire_ok=1
for pat in \
  'accessibilityLabel\("Setup Cloudflare"\)' \
  'accessibilityLabel\("Setup Vercel"\)' \
  'accessibilityLabel\("Setup PushCI"\)' \
  'ProviderTokenSetupSheet' \
  'pendingProviderTab' \
  'Contents/MacOS/vibevault-mcp'
do
  if ! rg -q "$pat" apps/VibeVaultApp packages/VaultCore cli --glob '*.swift'; then
    fail "wiring missing: $pat"
    wire_ok=0
  fi
done
[[ $wire_ok -eq 1 ]] && pass "Setup/token/deep-link/MCP path wiring"

# AX UI smoke — only if assistive access granted
if osascript -e 'tell application "System Events" to get name of first process' >/dev/null 2>&1; then
  skip "AX UI smoke not automated here (run scripts/tests/setup-flows-smoke.sh with Accessibility enabled for Terminal/Cursor)"
else
  skip "AX unavailable (enable Accessibility for the host app to click Setup sheets)"
fi

echo ""
echo "==> Summary: $PASS passed · $FAIL failed · $SKIP skipped"
[[ "$FAIL" -eq 0 ]]
