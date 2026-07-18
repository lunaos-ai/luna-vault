# Test & validation report

**Updated:** 2026-07-18

## Automated

| Suite | Result |
|-------|--------|
| `scripts/check-loc.sh` | Pass (0 over 200 LOC) |
| `EncryptedVaultStoreTests` | Pass (round-trip, tamper, legacy key migrate) |
| `VaultServiceTests` | Pass (audit + read-cache invalidation) |
| `MigratingVaultStoreTests` | Pass |
| `LicenseCodecTests` | Pass (forgery rejected) |
| `ProviderCredentialStoreTests` | Pass |
| `scripts/tests/setup-flows-smoke.sh` | Pass (bundle + CLI + wiring; AX optional) |
| `scripts/gtm-check.sh` | 0 fail, 2 warn (notary; brew tap) |

## Manual / blocked

| Check | Status |
|-------|--------|
| Notarized DMG Gatekeeper open | Blocked on `NOTARYTOOL_*` |
| $0 LS discount → webhook → VV1 email | Not re-verified this cycle |
| AX click Setup sheets | Needs Accessibility for host app |

## Commands

```bash
bash scripts/check-loc.sh
swift test --filter 'EncryptedVaultStoreTests|VaultServiceTests|MigratingVaultStoreTests|LicenseCodecTests'
bash scripts/tests/setup-flows-smoke.sh
bash scripts/gtm-check.sh
bash scripts/bundle-app.sh debug && open build/VibeVault.app
```
