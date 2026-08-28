#!/usr/bin/env bash
# Build Vibe Vault CLI + desktop inside WSL2 (Ubuntu) or native Linux.
# On Windows, run from a WSL shell:  bash scripts/build-wsl.sh
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

if ! command -v swift >/dev/null 2>&1; then
  echo "Swift toolchain required. On WSL/Ubuntu install Swift 6+ from https://www.swift.org/install/"
  exit 1
fi

echo "==> Building CLI + MCP"
sudo apt-get update -qq
sudo DEBIAN_FRONTEND=noninteractive apt-get install -y -qq libsqlite3-dev >/dev/null
rm -f Package.resolved
swift build -c release --product vibevault --product vibevault-mcp -j "${SWIFT_BUILD_JOBS:-2}"
ls -la .build/release/vibevault .build/release/vibevault-mcp

echo "==> Building VibeVaultDesktop (Gtk 4; needs Swift 6+)"
sudo DEBIAN_FRONTEND=noninteractive apt-get install -y -qq \
  libgtk-4-dev libglib2.0-dev pkg-config clang >/dev/null
(
  cd apps/VibeVaultDesktop
  rm -f Package.resolved
  swift build -c release --product VibeVaultDesktop -j "${SWIFT_BUILD_JOBS:-2}"
  ls -la .build/release/VibeVaultDesktop
)

echo "==> Done. Unlock with: vibevault session unlock"
