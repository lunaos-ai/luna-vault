#!/usr/bin/env bash
# Publish VibeVault.dmg + landing page for vibevault.lunaos.ai.
set -euo pipefail

cd "$(dirname "$0")/.."

DMG_SRC="${DMG_SRC:-build/VibeVault.dmg}"
PROJECT="${CF_PAGES_PROJECT:-lunaos-marketing}"
REPO="${LUNAOS_MARKETING_REPO:-lunaos-ai/lunaos-marketing}"
WORK="${MARKETING_WORKDIR:-build/lunaos-marketing}"
LANDING_SRC="marketing/landing/index.html"

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
if [ -d "marketing/landing/assets" ]; then
    mkdir -p "$WORK/vibevault/assets"
    cp -f marketing/landing/assets/*.png "$WORK/vibevault/assets/" 2>/dev/null || true
    echo "==> Assets → vibevault/assets/"
fi

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
/download/vibevault /downloads/VibeVault.dmg 302
/downloads/vibevault /downloads/VibeVault.dmg 302
/vibevault /vibevault/index.html 200
REDIR
elif ! grep -q "/vibevault" "$WORK/_redirects"; then
    echo "/vibevault /vibevault/index.html 200" >> "$WORK/_redirects"
fi

if [ -f "$DMG_SRC" ] && ! grep -q "VibeVault.dmg" "$WORK/_headers" 2>/dev/null; then
    cat >> "$WORK/_headers" <<'HDR'

/downloads/VibeVault.dmg
  Content-Type: application/x-apple-diskimage
  Content-Disposition: attachment; filename="VibeVault.dmg"
HDR
fi

echo "==> Deploying to Cloudflare Pages ($PROJECT)..."
(cd "$WORK" && wrangler pages deploy . --project-name="$PROJECT" --commit-dirty=true)

echo ""
echo "==> Live:"
echo "    https://vibevault.lunaos.ai/"
echo "    https://vibevault.lunaos.ai/download"
