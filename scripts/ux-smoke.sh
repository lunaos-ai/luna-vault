#!/usr/bin/env bash
# Full UX smoke: bundle app, launch animated sidebar tour with soft sounds.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

echo "==> Building + bundling..."
bash scripts/bundle-app.sh debug

BIN="$ROOT/build/VibeVault.app/Contents/MacOS/VibeVault"
echo "==> Stopping prior VibeVault..."
pkill -f 'VibeVault.app/Contents/MacOS/VibeVault' 2>/dev/null || true
sleep 0.5

echo "==> Launching UX smoke (VIBEVAULT_UX_SMOKE=1)..."
VIBEVAULT_UX_SMOKE=1 "$BIN" >/tmp/vibevault-ux-smoke.log 2>&1 &
PID=$!
sleep 1.2

osascript <<'APPLESCRIPT' || true
tell application "System Events"
  if exists process "VibeVault" then
    set frontmost of process "VibeVault" to true
  end if
end tell
APPLESCRIPT

echo "PID=$PID — tour cycles every sidebar pane (~9s) with toasts + soft clicks."
echo "Reduce Motion in System Settings disables motion; sounds off in Settings → Feedback."
sleep 11

if kill -0 "$PID" 2>/dev/null; then
  echo "==> Tour finished (app left running). Log: /tmp/vibevault-ux-smoke.log"
else
  echo "==> Process exited early. Log:"
  cat /tmp/vibevault-ux-smoke.log || true
fi
