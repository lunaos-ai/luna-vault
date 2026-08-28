#!/usr/bin/env bash
# UI smoke: Cloud Sync screen + Team license screen (app-driven + Accessibility checks).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"
LOG=/tmp/vibevault-ui-smoke.log
RESULT=/tmp/vibevault-ui-smoke-result.json
SHOT_DIR=/tmp/vibevault-ui-smoke-shots
AX_LOG=/tmp/vv-ui-ax.log
PASS=0
FAIL=0

pass() { echo "PASS $1"; PASS=$((PASS + 1)); }
fail() { echo "FAIL $1"; FAIL=$((FAIL + 1)); }

echo "==> Build debug app"
bash scripts/bundle-app.sh debug >/tmp/vv-ui-smoke-bundle.log 2>&1
pass "bundle-app"

BIN="$ROOT/build/VibeVault.app/Contents/MacOS/VibeVault"
pkill -f 'build/VibeVault.app/Contents/MacOS/VibeVault' 2>/dev/null || true
pkill -f '/Applications/VibeVault.app/Contents/MacOS/VibeVault' 2>/dev/null || true
sleep 0.5
rm -f "$RESULT" "$LOG" "$AX_LOG"
mkdir -p "$SHOT_DIR"

echo "==> Launch UI smoke (navigates Cloud Sync → Settings in the app window)"
echo "    Tip: run 'vibevault session unlock' first for full iCloud push coverage."
VIBEVAULT_UI_SMOKE=cloud-sync-team \
  VIBEVAULT_UI_SMOKE_PASSPHRASE='ui-smoke-sync-passphrase' \
  "$BIN" >"$LOG" 2>&1 &
PID=$!
sleep 2
osascript <<'APPLESCRIPT' || true
tell application "System Events"
  if exists process "VibeVault" then
    set frontmost of process "VibeVault" to true
  end if
end tell
APPLESCRIPT

for _ in $(seq 1 30); do
  [[ -f "$RESULT" ]] && break
  sleep 1
done
sleep 1

screencapture -x "$SHOT_DIR/cloud-sync-team-final.png" 2>/dev/null || true

echo "==> Accessibility UI checks (smoke app window, pid=$PID)"
cat > /tmp/vv-ui-ax.applescript <<'AXSCRIPT'
on run argv
  set targetPID to (item 1 of argv) as integer
  tell application "System Events"
    set vv to first process whose unix id is targetPID
    if vv is missing value then error "smoke app pid not found"
    set frontmost of vv to true
    delay 0.4
    set winName to name of window 1 of vv
    if winName is not "Settings" then error "expected Settings window, got " & winName
  end tell
end run
AXSCRIPT

if osascript /tmp/vv-ui-ax.applescript "$PID" >"$AX_LOG" 2>&1; then
  pass "accessibility settings window after team smoke"
else
  fail "accessibility settings window after team smoke"
  cat "$AX_LOG" || true
fi

if [[ -f "$RESULT" ]]; then
  pass "smoke result written"
  cat "$RESULT"
else
  fail "smoke result missing (see $LOG)"
  tail -30 "$LOG" || true
fi

if [[ -f "$RESULT" ]] && rg -q '"icloud_push":"ok"|"icloud_push":"skipped_session_locked"' "$RESULT"; then
  pass "icloud push via app environment"
else
  fail "icloud push via app environment"
fi

if [[ -f "$RESULT" ]] && rg -q '"icloud_after":"present"' "$RESULT"; then
  pass "icloud bundle present after push"
elif [[ -f "$RESULT" ]] && rg -q '"icloud_push":"skipped_session_locked"' "$RESULT"; then
  pass "icloud bundle unchanged (session locked; unlock first for push smoke)"
else
  fail "icloud bundle present after push"
fi

if [[ -f "$RESULT" ]] && rg -q '"team_ui":"ok"' "$RESULT"; then
  pass "team license ui smoke"
else
  fail "team license ui smoke"
fi

if [[ -f "$RESULT" ]] && rg -q '"cloud_sync_ui":"ok"' "$RESULT"; then
  pass "cloud sync ui navigation"
else
  fail "cloud sync ui navigation"
fi

CLI="$ROOT/build/VibeVault.app/Contents/Helpers/vibevault"
if VIBEVAULT_SYNC_PASSPHRASE='ui-smoke-sync-passphrase' \
  "$CLI" sync preview --path "$HOME/Library/Mobile Documents/com~apple~CloudDocs/Documents/VibeVault/Sync/vault.vvsync" \
  --passphrase-env VIBEVAULT_SYNC_PASSPHRASE >/tmp/vv-ui-preview.log 2>&1; then
  pass "cli preview of ui-created bundle"
else
  fail "cli preview of ui-created bundle"
  cat /tmp/vv-ui-preview.log || true
fi

kill "$PID" 2>/dev/null || true
echo ""
echo "==> Summary: $PASS passed · $FAIL failed"
echo "Screenshots: $SHOT_DIR"
echo "App log: $LOG"
[[ "$FAIL" -eq 0 ]]
