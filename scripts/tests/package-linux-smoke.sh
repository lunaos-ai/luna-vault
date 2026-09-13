#!/usr/bin/env bash
# Smoke-test Linux packaging scripts without a full Docker build.
# Uses placeholder binaries when release builds are absent.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"
mkdir -p build/smoke-bins
FAKE_CLI=build/smoke-bins/vibevault
FAKE_MCP=build/smoke-bins/vibevault-mcp
FAKE_DESKTOP=build/smoke-bins/VibeVaultDesktop
printf '#!/bin/sh\necho vibevault-smoke\n' > "$FAKE_CLI"
printf '#!/bin/sh\necho mcp-smoke\n' > "$FAKE_MCP"
printf '#!/bin/sh\necho desktop-smoke\n' > "$FAKE_DESKTOP"
chmod 755 "$FAKE_CLI" "$FAKE_MCP" "$FAKE_DESKTOP"

CLI_BIN="$ROOT/$FAKE_CLI" MCP_BIN="$ROOT/$FAKE_MCP" \
  TARGET_ARCH=smoke VIBEVAULT_VERSION=0.0.0+smoke \
  bash scripts/package-linux-cli.sh

DESKTOP_BIN="$ROOT/$FAKE_DESKTOP" \
  TARGET_ARCH=smoke VIBEVAULT_VERSION=0.0.0+smoke \
  bash scripts/package-linux-desktop.sh

CLI_BIN="$ROOT/$FAKE_CLI" MCP_BIN="$ROOT/$FAKE_MCP" \
  TARGET_ARCH=smoke VIBEVAULT_VERSION=0.0.0+smoke KIND=cli \
  bash scripts/package-linux-deb.sh

DESKTOP_BIN="$ROOT/$FAKE_DESKTOP" \
  TARGET_ARCH=smoke VIBEVAULT_VERSION=0.0.0+smoke KIND=desktop \
  bash scripts/package-linux-deb.sh

DESKTOP_BIN="$ROOT/$FAKE_DESKTOP" \
  TARGET_ARCH=smoke VIBEVAULT_VERSION=0.0.0+smoke \
  bash scripts/package-linux-appimage.sh

test -f build/vibevault-linux-smoke.tar.gz
test -f build/VibeVaultDesktop-linux-smoke.tar.gz
test -f build/vibevault_0.0.0+smoke_all.deb
test -f build/vibevault-desktop_0.0.0+smoke_all.deb
test -f build/VibeVaultDesktop-smoke.AppDir.tar.gz
tar -tzf build/vibevault-linux-smoke.tar.gz | grep -q 'bin/vibevault'
tar -tzf build/VibeVaultDesktop-linux-smoke.tar.gz | grep -q 'bin/VibeVaultDesktop'
python3 - <<'PY'
import pathlib
deb = pathlib.Path("build/vibevault_0.0.0+smoke_all.deb").read_bytes()
assert deb.startswith(b"!<arch>\n"), deb[:16]
PY
echo "package-linux-smoke OK"
