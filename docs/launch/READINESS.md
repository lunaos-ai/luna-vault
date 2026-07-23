# Launch Readiness Snapshot

Date: July 22, 2026

## Ready

- Public website: https://vibevault.lunaos.ai/
- Scanner page: https://vibevault.lunaos.ai/scan
- Security architecture page: https://vibevault.lunaos.ai/security
- Worker health endpoint: https://vibevault.lunaos.ai/health
- Install route: https://vibevault.lunaos.ai/download
- AI-agent landing page: https://vibevault.lunaos.ai/agents
- LLM-readable agent guidance: https://vibevault.lunaos.ai/llms.txt
- Chrome Web Store listing: https://chromewebstore.google.com/detail/vibe-vault-importer/nfeigikipagiccmhlolgfbeienkckbpc
- Landing page copy includes:
  - local-first architecture
  - provider sync
  - browser import privacy copy
  - optional encrypted sync positioning
  - random key generation formats
- DMG artifact exists: `build/VibeVault.dmg`
- Browser extension zip exists: `build/VibeVault-Browser-Importer.zip`
- Chrome store docs exist:
  - `extensions/browser-vibevault/store/listing.md`
  - `extensions/browser-vibevault/store/privacy.md`
  - `extensions/browser-vibevault/store/review-notes.md`
- Launch copy exists:
  - `docs/launch/LAUNCH_PACK.md`
  - `docs/launch/COMMUNITY_POSTS.md`
  - `docs/launch/PRODUCT_HUNT.md`
  - `docs/launch/GTM_RUNBOOK.md`

## Blocked

- Current DMG has no stapled notarization ticket.
- Current DMG is rejected by Gatekeeper.
- Current app is rejected by Gatekeeper.
- `NOTARYTOOL_APPLE_ID`, `NOTARYTOOL_TEAM_ID`, and `NOTARYTOOL_PASSWORD` are not available in the current shell.
- Apple Developer Program enrollment is blocked, so Developer ID signing and notarization are not currently available.
- Homebrew tap verification cannot run with current GitHub auth/repo access.
- Public posting requires owner accounts for HN, Reddit, X, Product Hunt, and communities.

## Current Launch Mode

CLI-first. Public install copy should point to source build and scanner usage.
Do not promote the unnotarized DMG as the default install path. Chrome importer
copy can link to the public Web Store listing.

## Last Verified Commands

```bash
vibevault scan
bash scripts/gtm-check.sh
swift test
swift build --product VibeVaultApp
xcrun stapler validate build/VibeVault.dmg
spctl -a -vv -t open build/VibeVault.dmg
spctl -a -vv build/VibeVault.app
curl -fsSL https://vibevault.lunaos.ai/health
```
