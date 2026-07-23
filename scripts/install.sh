#!/usr/bin/env bash
# One-liner install helper for GTM (CLI via Homebrew or build-from-source).
set -euo pipefail

echo "==> Vibe Vault install"

if command -v brew >/dev/null 2>&1; then
  if brew tap-info finsavvyai/tap &>/dev/null || brew tap finsavvyai/tap 2>/dev/null; then
    brew install vibevault || brew install --formula "$(dirname "$0")/../dist/homebrew/vibevault.rb"
  else
    echo "Tap not available yet — building from this checkout..."
    ROOT="$(cd "$(dirname "$0")/.." && pwd)"
    (cd "$ROOT" && swift build -c release --product vibevault --product vibevault-mcp --product vibevault-browser-host)

    BIN_DIR=""
    for candidate in "$(brew --prefix)/bin" /usr/local/bin; do
      if [ -d "$candidate" ] && [ -w "$candidate" ]; then
        BIN_DIR="$candidate"
        break
      fi
    done
    if [ -z "$BIN_DIR" ]; then
      BIN_DIR="$HOME/.local/bin"
      mkdir -p "$BIN_DIR"
    fi

    for bin in vibevault vibevault-mcp vibevault-browser-host; do
      ln -sf "$ROOT/.build/release/$bin" "$BIN_DIR/$bin"
    done
    echo "Linked vibevault, vibevault-mcp, and vibevault-browser-host into $BIN_DIR"

    if ! command -v vibevault >/dev/null 2>&1; then
      echo "WARNING: $BIN_DIR is not on your PATH."
      echo "Add it to your shell profile, e.g.:  export PATH=\"$BIN_DIR:\$PATH\""
      exit 1
    fi
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
echo "  vibevault browser install --browser chrome --extension-id nfeigikipagiccmhlolgfbeienkckbpc"
echo "  open https://vibevault.lunaos.ai/download   # menu-bar app"
