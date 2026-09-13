#!/usr/bin/env bash
# Build a Debian package from CLI or desktop binaries.
# KIND=cli (default) or desktop. Uses dpkg-deb when present, else GNU ar via Python.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

KIND="${KIND:-cli}"
ARCH_RAW="${TARGET_ARCH:-$(uname -m 2>/dev/null || echo unknown)}"
case "$ARCH_RAW" in
  x86_64|amd64) DEB_ARCH=amd64 ;;
  aarch64|arm64) DEB_ARCH=arm64 ;;
  smoke) DEB_ARCH=all ;;
  *) DEB_ARCH="$ARCH_RAW" ;;
esac

if [[ -n "${VIBEVAULT_VERSION:-}" ]]; then
  RAW_VERSION="$VIBEVAULT_VERSION"
else
  RAW_VERSION="$(GIT_TERMINAL_PROMPT=0 git -c safe.directory=* describe --tags --always 2>/dev/null || true)"
  RAW_VERSION="${RAW_VERSION:-0.1.0}"
fi
VERSION="${RAW_VERSION#v}"
if [[ ! "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+([+.~-].*)?$ ]]; then
  VERSION="0.0.0+${VERSION}"
fi

work="$(mktemp -d "${TMPDIR:-/tmp}/vv-deb.XXXXXX")"
trap 'rm -rf "$work"' EXIT
data="$work/data"
mkdir -p "$data/usr/bin" "$data/usr/share/doc"

if [[ "$KIND" == "desktop" ]]; then
  BIN="${DESKTOP_BIN:-$ROOT/apps/VibeVaultDesktop/.build/release/VibeVaultDesktop}"
  if [[ ! -x "$BIN" ]]; then
    echo "missing desktop binary: $BIN" >&2
    exit 1
  fi
  PKG=vibevault-desktop
  depends="libgtk-4-1, libglib2.0-0"
  desc_short="Local-first secret manager desktop shell"
  desc_long="Gtk 4 shell (SwiftCrossUI) sharing the CLI vault."
  install -m 755 "$BIN" "$data/usr/bin/VibeVaultDesktop"
  mkdir -p "$data/usr/share/applications"
  cat > "$data/usr/share/applications/vibevault-desktop.desktop" <<EOF
[Desktop Entry]
Type=Application
Name=Vibe Vault
Comment=Local-first secret manager for AI coding workflows
Exec=/usr/bin/VibeVaultDesktop
Terminal=false
Categories=Utility;Security;
Keywords=secrets;env;vault;
EOF
  mkdir -p "$data/usr/share/doc/vibevault-desktop"
  printf '%s\n' "Vibe Vault Desktop ${VERSION}" > "$data/usr/share/doc/vibevault-desktop/README"
else
  CLI="${CLI_BIN:-$ROOT/.build/release/vibevault}"
  MCP="${MCP_BIN:-$ROOT/.build/release/vibevault-mcp}"
  if [[ ! -x "$CLI" || ! -x "$MCP" ]]; then
    echo "missing CLI binaries. build first: bash scripts/build-linux.sh" >&2
    exit 1
  fi
  PKG=vibevault
  depends="libc6, libsqlite3-0"
  desc_short="Local-first secret manager CLI for AI coding agents"
  desc_long="CLI and MCP server. Recommends libsecret for the OS keyring."
  install -m 755 "$CLI" "$data/usr/bin/vibevault"
  install -m 755 "$MCP" "$data/usr/bin/vibevault-mcp"
  mkdir -p "$data/usr/share/doc/vibevault"
  printf '%s\n' "Vibe Vault CLI ${VERSION}" > "$data/usr/share/doc/vibevault/README"
fi

size_kb="$(du -sk "$data" | awk '{print $1}')"
mkdir -p "$work/control"
recommends=""
if [[ "$KIND" != "desktop" ]]; then
  recommends="Recommends: libsecret-1-0, gnome-keyring | keepassxc
"
fi
cat > "$work/control/control" <<EOF
Package: ${PKG}
Version: ${VERSION}
Section: utils
Priority: optional
Architecture: ${DEB_ARCH}
Maintainer: LunaOS <security@lunaos.ai>
Depends: ${depends}
${recommends}Installed-Size: ${size_kb}
Homepage: https://vibevault.lunaos.ai/
Description: ${desc_short}
 ${desc_long}
EOF

( cd "$work/control" && tar --format=ustar -czf "$work/control.tar.gz" control )
( cd "$data" && tar --format=ustar -czf "$work/data.tar.gz" usr )
printf '2.0\n' > "$work/debian-binary"

mkdir -p "$ROOT/build"
OUT="$ROOT/build/${PKG}_${VERSION}_${DEB_ARCH}.deb"
if command -v dpkg-deb >/dev/null 2>&1; then
  rm -rf "$work/pkg"
  mkdir -p "$work/pkg/DEBIAN"
  cp "$work/control/control" "$work/pkg/DEBIAN/control"
  cp -a "$data/." "$work/pkg/"
  dpkg-deb --root-owner-group --build "$work/pkg" "$OUT"
else
  python3 - "$work/control.tar.gz" "$work/data.tar.gz" "$work/debian-binary" "$OUT" <<'PY'
import pathlib, sys

def entry(name: str, data: bytes) -> bytes:
    hdr = (
        f"{name:<16}{0:<12}{0:<6}{0:<6}{'100644':<8}{len(data):<10}`\n"
    ).encode("ascii")
    if len(hdr) != 60:
        raise SystemExit(f"bad ar header length {len(hdr)}")
    pad = b"\n" if len(data) % 2 else b""
    return hdr + data + pad

control, data, debian, out = map(pathlib.Path, sys.argv[1:])
blob = b"!<arch>\n"
blob += entry("debian-binary", debian.read_bytes())
blob += entry("control.tar.gz", control.read_bytes())
blob += entry("data.tar.gz", data.read_bytes())
out.write_bytes(blob)
PY
fi

echo "packaged $OUT"
