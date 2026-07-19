#!/usr/bin/env bash
# Safer GitHub Release from a version tag (v0.1.0).
# Called by .github/workflows/release.yml — uses env, not interpolated event fields in shell.
set -euo pipefail

TAG="${TAG:?TAG env required}"
NOTES_FILE="${NOTES_FILE:-CHANGELOG.md}"

notes=$(awk '
  /^## \[/{ if (found) exit; found=1; next }
  found { print }
' "$NOTES_FILE")

if [ -z "${notes// }" ]; then
  notes="See CHANGELOG.md for details."
fi

assets=(
  ".build/release/vibevault"
  ".build/release/vibevault-mcp"
)

for optional in \
  ".build/release/vibevault-browser-host" \
  "build/VibeVault.dmg" \
  "${BROWSER_EXTENSION_ZIP:-build/VibeVault-Browser-Importer.zip}"
do
  if [ -f "$optional" ]; then
    assets+=("$optional")
  fi
done

gh release create "$TAG" \
  --title "Vibe Vault $TAG" \
  --notes "$notes" \
  "${assets[@]}"
