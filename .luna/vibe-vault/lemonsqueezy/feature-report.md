# Feature report: Lemon Squeezy Team license

**Date:** 2026-07-18  
**Plan:** `.luna/vibe-vault/lemonsqueezy/plan.md`

## Implemented

| Deliverable | Path |
|-------------|------|
| Offline Ed25519 license codec | `packages/VaultCore/.../License/` |
| Embedded public key | `LicensePublicKey.swift` |
| Keychain prefs store | `LicenseStore.swift` |
| Checkout URL prefs / env | `LemonSqueezyConfig.swift` |
| Settings → Team license | `TeamLicenseSection.swift` |
| `env.isTeamLicensed` + badge | `AppEnvironment+License.swift`, sidebar footer |
| CLI `license activate\|status\|deactivate\|issue` | `cli/vibevault/Commands/LicenseCommand.swift` |
| Keygen script | `scripts/gen-license-keys.swift` |
| Issue wrapper | `scripts/issue-license.sh` |
| Store config + webhook notes | `dist/lemonsqueezy/` |
| Landing Team CTA | `marketing/landing/index.html` |

## Model

- Solo: free, unchanged
- Team: Lemon Squeezy checkout → signed `VV1.…` → offline activate
- No phone-home on verify

## Operator setup (remaining)

1. Create Lemon Squeezy product/variant; replace `REPLACE_VARIANT_ID` in checkout URL
2. Keep `dist/lemonsqueezy/private.b64` gitignored (or `VIBEVAULT_LICENSE_PRIVATE_KEY`)
3. Wire webhook to `bash scripts/issue-license.sh …` and email the key
4. Before production: rotate keypair if this repo’s public key was ever treated as final

## Verify

```bash
swift test --filter LicenseCodecTests
bash scripts/check-loc.sh
swift run vibevault license status
bash scripts/issue-license.sh --email you@co.com --seats 5 --order-id ord_1
# then: vibevault license activate 'VV1.…'
```

All 6 LicenseCodecTests passed; 0 Swift files over 200 LOC.
