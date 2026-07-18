# GTM Plan — Vibe Vault 0.1

## Goal

Ship a launch-ready wrap around the existing product: strangers can **find → trust → install → wow → share** in under 60 seconds.

## Workstreams

| # | Workstream | In-repo | Needs external |
|---|------------|---------|----------------|
| 1 | Version + CHANGELOG + LICENSE | Yes | — |
| 2 | Homebrew formula (tap-ready) | Yes | Push to `luna-os/homebrew-tap` |
| 3 | Landing page (download + brew + 15s pitch) | Yes (`marketing/`) | Deploy to lunaos-marketing |
| 4 | README / badges / install one-liner | Yes | — |
| 5 | Show HN + X launch pack | Yes (`docs/launch/`) | Post day-of |
| 6 | Cursor Directory listing draft | Yes | Submit listing |
| 7 | Release checklist + gtm-ready script | Yes | Notary credentials for notarize |
| 8 | GitHub Release workflow | Yes | Tag push |

## Out of band (credentials)

- Apple notarization (`NOTARYTOOL_*`)
- `gh release create` after first signed DMG
- Submit Homebrew tap PR
- Product Hunt (after notarized build + landing live)

## Success criteria

- [ ] `0.1.0` tagged in code + CHANGELOG
- [ ] LICENSE present
- [ ] `brew`-ready formula exists
- [ ] Landing HTML ready to deploy
- [ ] Launch copy ready to paste
- [ ] `scripts/gtm-check.sh` passes except notarize (warn-only without credentials)
