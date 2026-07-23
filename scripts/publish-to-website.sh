#!/usr/bin/env bash
# Publish VibeVault.dmg + landing page for vibevault.lunaos.ai.
set -euo pipefail

cd "$(dirname "$0")/.."

DMG_SRC="${DMG_SRC:-build/VibeVault.dmg}"
PROJECT="${CF_PAGES_PROJECT:-lunaos-marketing}"
REPO="${LUNAOS_MARKETING_REPO:-lunaos-ai/lunaos-marketing}"
WORK="${MARKETING_WORKDIR:-build/lunaos-marketing}"
LANDING_SRC="marketing/landing/index.html"
ROOT="$(pwd)"
WRANGLER_BIN="${WRANGLER_BIN:-}"

ensure_node_path() {
    if command -v node >/dev/null 2>&1; then
        return
    fi
    local bundled_node="$HOME/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/bin/node"
    if [ -x "$bundled_node" ]; then
        export PATH="$(dirname "$bundled_node"):$PATH"
    fi
}

resolve_wrangler() {
    ensure_node_path
    if [ -n "$WRANGLER_BIN" ]; then
        return
    fi
    if command -v wrangler >/dev/null 2>&1; then
        WRANGLER_BIN="$(command -v wrangler)"
    elif [ -x "$ROOT/workers/vibevault/node_modules/.bin/wrangler" ]; then
        WRANGLER_BIN="$ROOT/workers/vibevault/node_modules/.bin/wrangler"
    elif command -v npx >/dev/null 2>&1; then
        WRANGLER_BIN="npx wrangler"
    else
        echo "error: required command not found: wrangler" >&2
        exit 127
    fi
}

if [ ! -d "$WORK/.git" ]; then
    echo "==> Cloning $REPO..."
    rm -rf "$WORK"
    if command -v gh >/dev/null 2>&1; then
        gh repo clone "$REPO" "$WORK" -- --depth 1
    else
        git clone --depth 1 "https://github.com/$REPO.git" "$WORK"
    fi
fi

# Landing (GTM)
mkdir -p "$WORK/vibevault"
if [ -f "$LANDING_SRC" ]; then
    cp -f "$LANDING_SRC" "$WORK/vibevault/index.html"
    echo "==> Landing → vibevault/index.html"
fi
if [ -f "marketing/landing/llms.txt" ]; then
    cp -f "marketing/landing/llms.txt" "$WORK/vibevault/llms.txt"
    echo "==> llms.txt → vibevault/llms.txt"
fi
if [ -d "marketing/landing/assets" ]; then
    mkdir -p "$WORK/vibevault/assets"
    cp -f marketing/landing/assets/*.png "$WORK/vibevault/assets/" 2>/dev/null || true
    echo "==> Assets → vibevault/assets/"
fi
for page in install scan security agents; do
    if [ -d "marketing/landing/$page" ]; then
        rm -rf "$WORK/vibevault/$page"
        mkdir -p "$WORK/vibevault/$page"
        cp -R "marketing/landing/$page/." "$WORK/vibevault/$page/"
        echo "==> $page page → vibevault/$page/"
    fi
done

# DMG (optional if not built yet — still publish landing)
if [ -f "$DMG_SRC" ]; then
    mkdir -p "$WORK/downloads"
    cp -f "$DMG_SRC" "$WORK/downloads/VibeVault.dmg"
    echo "==> DMG → downloads/VibeVault.dmg"
else
    echo "warn: $DMG_SRC missing — publishing landing only (run scripts/release.sh for DMG)"
fi

if ! grep -q "downloads/VibeVault" "$WORK/_redirects" 2>/dev/null; then
    cat >> "$WORK/_redirects" <<'REDIR'

# ===== Vibe Vault =====
/download/vibevault /vibevault/install/index.html 302
/downloads/vibevault /downloads/VibeVault.dmg 302
/vibevault /vibevault/index.html 200
/vibevault/install /vibevault/install/index.html 200
/vibevault/scan /vibevault/scan/index.html 200
/vibevault/security /vibevault/security/index.html 200
/vibevault/agents /vibevault/agents/index.html 200
REDIR
elif ! grep -q "/vibevault" "$WORK/_redirects"; then
    echo "/vibevault /vibevault/index.html 200" >> "$WORK/_redirects"
fi
for page in install scan security agents; do
    if ! grep -q "/vibevault/$page" "$WORK/_redirects" 2>/dev/null; then
        echo "/vibevault/$page /vibevault/$page/index.html 200" >> "$WORK/_redirects"
    fi
done

if [ -f "$DMG_SRC" ] && ! grep -q "VibeVault.dmg" "$WORK/_headers" 2>/dev/null; then
    cat >> "$WORK/_headers" <<'HDR'

/downloads/VibeVault.dmg
  Content-Type: application/x-apple-diskimage
  Content-Disposition: attachment; filename="VibeVault.dmg"
HDR
fi

echo "==> Deploying to Cloudflare Pages ($PROJECT)..."
resolve_wrangler
(cd "$WORK" && $WRANGLER_BIN pages deploy . --project-name="$PROJECT" --commit-dirty=true)

echo ""
echo "==> Live:"
echo "    https://vibevault.lunaos.ai/"
echo "    https://vibevault.lunaos.ai/download"
