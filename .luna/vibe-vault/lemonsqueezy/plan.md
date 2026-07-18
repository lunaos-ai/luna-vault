# Lemon Squeezy + Team license plan

## Model (matches CLAUDE.md)

- **Solo**: free, no network, no paywall
- **Team**: buy on Lemon Squeezy → receive signed license key → activate offline
- Verification: **Ed25519** against embedded public key — **no phone-home**

## Flow

```
Buyer → Lemon Squeezy Checkout
      → order_created webhook (or manual issue script)
      → signed VV1.<payload>.<sig> emailed / shown
      → vibevault license activate KEY  (or Settings paste)
      → Keychain stores key; app unlocks isTeam
```

## In-repo deliverables

1. `LicenseCodec` + `LicenseStore` + embedded pubkey
2. Settings Team section + open checkout
3. CLI `license activate|status|deactivate`
4. `scripts/gen-license-keys.swift` + `scripts/issue-license.swift`
5. `dist/lemonsqueezy/config.example.json` + webhook notes
6. Landing Team CTA

## Team unlock (v0.1)

`env.isTeamLicensed` gates: Team badge, seats display, placeholder for future relay/shared vault.
Solo path unchanged.
