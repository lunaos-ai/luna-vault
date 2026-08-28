#!/usr/bin/env bash
# Smoke-build the cross-platform desktop shell on the host (macOS AppKit backend).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT/apps/VibeVaultDesktop"
swift build -c release --product VibeVaultDesktop
echo "==> Built: $ROOT/apps/VibeVaultDesktop/.build/release/VibeVaultDesktop"
echo "    macOS production UI remains VibeVaultApp (SwiftUI)."
