# Vibe Vault marketing assets

| Path | Purpose |
|------|---------|
| `landing/index.html` | Public pitch page → deploy as `lunaos.ai/vibevault` |
| `../docs/launch/LAUNCH_PACK.md` | Show HN / X / Reddit paste pack |
| `../dist/homebrew/` | Homebrew formula |
| `../dist/cursor-directory/` | Cursor Directory submission draft |

## Deploy landing (+ DMG if built)

```bash
bash scripts/release.sh          # builds DMG (optional before)
bash scripts/publish-to-website.sh
```

Requires `gh` access to `lunaos-ai/lunaos-marketing` and `wrangler` authenticated to Cloudflare Pages.
