#!/usr/bin/env bash
# One-liner install helper for GTM (CLI via Homebrew or build-from-source).
set -euo pipefail

echo "==> Vibe Vault install"

if command -v brew >/dev/null 2>&1; then
  if brew tap-info luna-os/tap &>/dev/null || brew tap luna-os/tap 2>/dev/null; then
    brew install vibevault || brew install --formula "$(dirname "$0")/../dist/homebrew/vibevault.rb"
  else
    echo "Tap not available yet — building from this checkout..."
    ROOT="$(cd "$(dirname "$0")/.." && pwd)"
    (cd "$ROOT" && swift build -c release --product vibevault --product vibevault-mcp)
    echo "Binaries: $ROOT/.build/release/vibevault"
  fi
else
  echo "Homebrew not found. Download the app: https://vibevault.lunaos.ai/download"
  exit 1
fi

echo ""
echo "Next:"
echo "  vibevault mcp install --client all"
echo "  vibevault skill install"
echo "  vibevault cursor prepare"
echo "  open https://vibevault.lunaos.ai/download   # menu-bar app"
