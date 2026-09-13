#!/usr/bin/env bash
# Package vibevault + vibevault-mcp into a relocatable Linux tarball.
# Run after scripts/build-linux.sh (or a native Linux release build).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

CLI="${CLI_BIN:-$ROOT/.build/release/vibevault}"
MCP="${MCP_BIN:-$ROOT/.build/release/vibevault-mcp}"
ARCH="${TARGET_ARCH:-$(uname -m 2>/dev/null || echo unknown)}"
if [[ -n "${VIBEVAULT_VERSION:-}" ]]; then
  VERSION="$VIBEVAULT_VERSION"
else
  VERSION="$(GIT_TERMINAL_PROMPT=0 git -c safe.directory=* describe --tags --always 2>/dev/null || true)"
  VERSION="${VERSION:-0.1.0}"
fi
STAGE="$ROOT/build/vibevault-linux-${ARCH}"
OUT="$ROOT/build/vibevault-linux-${ARCH}.tar.gz"

if [[ ! -x "$CLI" || ! -x "$MCP" ]]; then
  echo "missing release binaries. build first:" >&2
  echo "  bash scripts/build-linux.sh" >&2
  echo "expected: $CLI and $MCP" >&2
  exit 1
fi

rm -rf "$STAGE"
mkdir -p "$STAGE/bin" "$STAGE/share/doc/vibevault"
cp -f "$CLI" "$STAGE/bin/vibevault"
cp -f "$MCP" "$STAGE/bin/vibevault-mcp"
chmod 755 "$STAGE/bin/vibevault" "$STAGE/bin/vibevault-mcp"

cat > "$STAGE/install.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
PREFIX="${PREFIX:-$HOME/.local}"
ROOT="$(cd "$(dirname "$0")" && pwd)"
mkdir -p "$PREFIX/bin"
install -m 755 "$ROOT/bin/vibevault" "$PREFIX/bin/vibevault"
install -m 755 "$ROOT/bin/vibevault-mcp" "$PREFIX/bin/vibevault-mcp"
echo "Installed to $PREFIX/bin"
echo "Ensure $PREFIX/bin is on PATH, then: vibevault session unlock"
EOF
chmod 755 "$STAGE/install.sh"

cat > "$STAGE/README.md" <<EOF
# Vibe Vault Linux CLI ${VERSION}

Contents: \`vibevault\` (CLI) and \`vibevault-mcp\` (MCP server).

## Install

\`\`\`bash
./install.sh
# or: PREFIX=/usr/local ./install.sh
\`\`\`

## First use

\`\`\`bash
vibevault session unlock --minutes 30
vibevault --help
vibevault mcp install --client all
\`\`\`

Data dir: \`\${XDG_DATA_HOME:-~/.local/share}/vibe-vault\`
Master key: OS keyring (libsecret) when a session keyring is present, otherwise a mode-0600 file. See docs/WINDOWS_AND_LINUX.md.
EOF

cp -f "$STAGE/README.md" "$STAGE/share/doc/vibevault/README.md"

mkdir -p "$(dirname "$OUT")"
tar -C "$(dirname "$STAGE")" -czf "$OUT" "$(basename "$STAGE")"
echo "packaged $OUT ($(du -h "$OUT" | awk '{print $1}')) version=$VERSION arch=$ARCH"
