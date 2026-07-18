# Deployment report

**Updated:** 2026-07-18  
**Status:** Soft-launch (marketing Worker live; notarized app not yet)

## Marketing Worker (`vibevault.lunaos.ai`)

| Item | Value |
|------|-------|
| First deploy | 2026-07-18T12:34:27Z |
| Probe | `GET /` → 200; `GET /api/checkout` → 200 `configured: true` |
| Source | `workers/vibevault/` via wrangler |

## Native app

| Item | Value |
|------|-------|
| Version | 0.1.0 (CHANGELOG) |
| Notarized DMG | Pending (`NOTARYTOOL_*`) |
| GitHub Release `v0.1.0` | Pending tag |
| Homebrew tap | Formula in-repo; tap push pending |

## Next deploy checklist

1. Commit security remediations on `main`
2. `NOTARIZE=1 bash scripts/release.sh`
3. Tag `v0.1.0` + GitHub Release
4. Push `dist/homebrew/vibevault.rb` to `luna-os/homebrew-tap`
5. Redeploy Worker if landing/copy changed: `cd workers/vibevault && npx wrangler deploy`
