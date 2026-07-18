# Feature report: GTM pack 0.1.0

**Date:** 2026-07-15  
**Plan:** `.luna/vibe-vault/gtm/plan.md`

## Implemented in-repo

| Deliverable | Path |
|-------------|------|
| LICENSE (MIT + app scope note) | `LICENSE` |
| CHANGELOG 0.1.0 | `CHANGELOG.md` |
| CLI version bump | `cli/vibevault/VibeVault.swift` → `0.1.0` |
| Homebrew formula | `dist/homebrew/vibevault.rb` |
| Landing page | `marketing/landing/index.html` |
| Publish landing + DMG | `scripts/publish-to-website.sh` |
| Launch pack (HN/X/Reddit/PH) | `docs/launch/LAUNCH_PACK.md` |
| Cursor Directory draft | `dist/cursor-directory/vibe-vault.json` |
| Install one-liner script | `scripts/install.sh` |
| GTM readiness check | `scripts/gtm-check.sh` |
| GitHub Release workflow | `.github/workflows/release.yml` + `scripts/gh-release.sh` |
| README polish | badges, install, prepare |

## Remaining (credentials / human)

1. Set `NOTARYTOOL_*` → `NOTARIZE=1 NOTARIZE_DMG=1 bash scripts/release.sh`
2. `bash scripts/publish-to-website.sh` (gh + wrangler)
3. Push formula to `luna-os/homebrew-tap`
4. `git tag v0.1.0 && git push --tags` (triggers release workflow)
5. Post `docs/launch/LAUNCH_PACK.md`
6. Submit `dist/cursor-directory/vibe-vault.json` to Cursor Directory

## Verify

```bash
bash scripts/gtm-check.sh
open marketing/landing/index.html
```
