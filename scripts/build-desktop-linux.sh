#!/usr/bin/env bash
# Build VibeVaultDesktop for Linux (Gtk 4) via Docker.
# SwiftCrossUI 0.9 needs Swift 6 (body macros / BitwiseCopyable); CLI stays on 5.10.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
IMAGE="${SWIFT_DESKTOP_LINUX_IMAGE:-swift:6.0-jammy}"
DESKTOP="$ROOT/apps/VibeVaultDesktop"

echo "==> Building VibeVaultDesktop in $IMAGE (Gtk 4)"
docker run --rm \
  -v "$ROOT:/src" \
  -w /src/apps/VibeVaultDesktop \
  "$IMAGE" \
  bash -lc '
    set -euo pipefail
    git config --global --add safe.directory "*"
    rm -f Package.resolved
    if [ "${FORCE_CLEAN:-0}" = "1" ]; then
      rm -rf .build
    fi
    apt-get update -qq
    DEBIAN_FRONTEND=noninteractive apt-get install -y -qq \
      libgtk-4-dev libglib2.0-dev libsqlite3-dev pkg-config clang >/dev/null
    # Cap jobs: full -j OOMs Docker Desktop (~8GB) during BoringSSL + VaultCore.
    JOBS="${SWIFT_BUILD_JOBS:-1}"
    swift build -c release --product VibeVaultDesktop -j "$JOBS"
    ls -la .build/release/VibeVaultDesktop
  '

echo "==> Done. Binary: apps/VibeVaultDesktop/.build/release/VibeVaultDesktop"
