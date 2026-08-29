#!/usr/bin/env bash
# Package VibeVaultDesktop (Gtk) into a relocatable Linux tarball.
# Run after scripts/build-desktop-linux.sh.
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
STAGE="$ROOT/build/VibeVaultDesktop-linux-${ARCH}"
OUT="$ROOT/build/VibeVaultDesktop-linux-${ARCH}.tar.gz"

if [[ ! -x "$BIN" ]]; then
  echo "missing desktop binary. build first:" >&2
  echo "  bash scripts/build-desktop-linux.sh" >&2
  echo "expected: $BIN" >&2
  exit 1
fi

rm -rf "$STAGE"
mkdir -p "$STAGE/bin" "$STAGE/share/applications" "$STAGE/share/doc/VibeVaultDesktop"
cp -f "$BIN" "$STAGE/bin/VibeVaultDesktop"
chmod 755 "$STAGE/bin/VibeVaultDesktop"

cat > "$STAGE/share/applications/vibevault-desktop.desktop" <<EOF
[Desktop Entry]
Type=Application
Name=Vibe Vault
Comment=Local-first secret manager for AI coding workflows
Exec=VibeVaultDesktop
Terminal=false
Categories=Utility;Security;
Keywords=secrets;env;vault;
EOF

cat > "$STAGE/install.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
PREFIX="${PREFIX:-$HOME/.local}"
ROOT="$(cd "$(dirname "$0")" && pwd)"
mkdir -p "$PREFIX/bin" "$PREFIX/share/applications"
install -m 755 "$ROOT/bin/VibeVaultDesktop" "$PREFIX/bin/VibeVaultDesktop"
install -m 644 "$ROOT/share/applications/vibevault-desktop.desktop" \
  "$PREFIX/share/applications/vibevault-desktop.desktop"
# Point Exec at the installed binary.
sed -i.bak "s|^Exec=.*|Exec=$PREFIX/bin/VibeVaultDesktop|" \
  "$PREFIX/share/applications/vibevault-desktop.desktop"
rm -f "$PREFIX/share/applications/vibevault-desktop.desktop.bak"
echo "Installed VibeVaultDesktop to $PREFIX/bin"
echo "Requires Gtk 4 runtime libraries (libgtk-4-1 on Debian/Ubuntu)."
echo "Unlock with the Unlock tab or: vibevault session unlock"
EOF
chmod 755 "$STAGE/install.sh"

cat > "$STAGE/README.md" <<EOF
# Vibe Vault Desktop (Linux) ${VERSION}

Gtk 4 shell via SwiftCrossUI. Requires Gtk 4 shared libraries at runtime.

## Install

\`\`\`bash
# Debian/Ubuntu runtime deps
sudo apt-get install -y libgtk-4-1 libglib2.0-0

./install.sh
\`\`\`

## Notes

- Same vault as the CLI under \`\${XDG_DATA_HOME:-~/.local/share}/vibe-vault\`
- No Touch ID — use the Unlock tab or \`vibevault session unlock\`
- Full docs: https://github.com/lunaos-ai/luna-vault/blob/main/docs/WINDOWS_AND_LINUX.md
EOF
cp -f "$STAGE/README.md" "$STAGE/share/doc/VibeVaultDesktop/README.md"

mkdir -p "$(dirname "$OUT")"
tar -C "$(dirname "$STAGE")" -czf "$OUT" "$(basename "$STAGE")"
echo "packaged $OUT ($(du -h "$OUT" | awk '{print $1}')) version=$VERSION arch=$ARCH"
