#!/usr/bin/env bash
# Stage VibeVaultDesktop as an AppDir and optionally wrap it with appimagetool.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

BIN="${DESKTOP_BIN:-$ROOT/apps/VibeVaultDesktop/.build/release/VibeVaultDesktop}"
ARCH="${TARGET_ARCH:-$(uname -m 2>/dev/null || echo unknown)}"
if [[ -n "${VIBEVAULT_VERSION:-}" ]]; then
  VERSION="$VIBEVAULT_VERSION"
else
  VERSION="$(GIT_TERMINAL_PROMPT=0 git -c safe.directory=* describe --tags --always 2>/dev/null || true)"
  VERSION="${VERSION:-0.1.0}"
fi

if [[ ! -x "$BIN" ]]; then
  echo "missing desktop binary. build first: bash scripts/build-desktop-linux.sh" >&2
  echo "expected: $BIN" >&2
  exit 1
fi

APPDIR="$ROOT/build/VibeVaultDesktop-${ARCH}.AppDir"
OUT_TAR="$ROOT/build/VibeVaultDesktop-${ARCH}.AppDir.tar.gz"
rm -rf "$APPDIR"
mkdir -p "$APPDIR/usr/bin" "$APPDIR/usr/share/applications"
cp -f "$BIN" "$APPDIR/usr/bin/VibeVaultDesktop"
chmod 755 "$APPDIR/usr/bin/VibeVaultDesktop"

cat > "$APPDIR/AppRun" <<'EOF'
#!/bin/sh
HERE="$(dirname "$(readlink -f "$0" 2>/dev/null || echo "$0")")"
exec "$HERE/usr/bin/VibeVaultDesktop" "$@"
EOF
chmod 755 "$APPDIR/AppRun"

cat > "$APPDIR/vibevault.desktop" <<EOF
[Desktop Entry]
Type=Application
Name=Vibe Vault
Comment=Local-first secret manager for AI coding workflows
Exec=VibeVaultDesktop
Icon=vibevault
Terminal=false
Categories=Utility;Security;
EOF
cp "$APPDIR/vibevault.desktop" "$APPDIR/usr/share/applications/vibevault.desktop"

# 1x1 PNG placeholder; AppImage requires an icon next to the desktop file.
python3 - "$APPDIR/vibevault.png" <<'PY'
import base64, pathlib, sys
png = base64.b64decode(
    "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg=="
)
pathlib.Path(sys.argv[1]).write_bytes(png)
PY

tar -C "$(dirname "$APPDIR")" -czf "$OUT_TAR" "$(basename "$APPDIR")"
echo "packaged $OUT_TAR"

maybe_appimagetool() {
  if command -v appimagetool >/dev/null 2>&1; then
    echo appimagetool
    return
  fi
  if [[ "${DOWNLOAD_APPIMAGETOOL:-0}" != "1" ]]; then
    return
  fi
  local tool_arch="$ARCH"
  case "$ARCH" in
    x86_64|amd64) tool_arch=x86_64 ;;
    aarch64|arm64) tool_arch=aarch64 ;;
    *) return ;;
  esac
  local url="https://github.com/AppImage/appimagetool/releases/download/continuous/appimagetool-${tool_arch}.AppImage"
  local dest="$ROOT/build/appimagetool-${tool_arch}.AppImage"
  mkdir -p "$ROOT/build"
  if command -v curl >/dev/null 2>&1; then
    curl -fsSL "$url" -o "$dest" || return
  elif command -v wget >/dev/null 2>&1; then
    wget -q "$url" -O "$dest" || return
  else
    return
  fi
  chmod 755 "$dest"
  echo "$dest"
}

TOOL="$(maybe_appimagetool || true)"
if [[ -n "${TOOL:-}" ]]; then
  APPIMAGE="$ROOT/build/VibeVaultDesktop-${ARCH}.AppImage"
  if ! ARCH="$ARCH" APPIMAGE_EXTRACT_AND_RUN=1 "$TOOL" "$APPDIR" "$APPIMAGE"; then
    echo "appimagetool failed; AppDir tarball is the desktop artifact"
  else
    echo "packaged $APPIMAGE"
  fi
else
  echo "appimagetool not found; AppDir tarball is the desktop artifact"
fi
