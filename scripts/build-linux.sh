#!/usr/bin/env bash
# Build vibevault CLI for Linux (Docker). Native Windows: scripts/build-windows.ps1.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
IMAGE="${SWIFT_LINUX_IMAGE:-swift:5.10-jammy}"

echo "==> Building vibevault CLI in $IMAGE"
docker run --rm \
  -v "$ROOT:/src" \
  -w /src \
  "$IMAGE" \
  bash -lc 'git config --global --add safe.directory "*" && rm -f Package.resolved && apt-get update -qq && DEBIAN_FRONTEND=noninteractive apt-get install -y -qq libsqlite3-dev >/dev/null && swift build -c release --product vibevault && swift build -c release --product vibevault-mcp'

echo "==> Linux binaries:"
docker run --rm -v "$ROOT:/src" -w /src "$IMAGE" \
  bash -lc 'ls -la .build/release/vibevault .build/release/vibevault-mcp'
