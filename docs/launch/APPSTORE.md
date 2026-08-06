# Vibe Vault — Mac App Store submission

## Prerequisites

- Apple Developer Program membership (paid)
- App Store Connect record for bundle ID `dev.vibevault`
- A Mac App Distribution certificate + private key in the CI runner keychain
- A Mac Installer Distribution certificate
- A Mac App Store provisioning profile for `dev.vibevault`
- App Store Connect API Key (Issuer ID + Key ID + `.p8` private key)

## Local upload

```bash
export APPSTORE_API_KEY_ID="ABCDEF1234"
export APPSTORE_API_ISSUER_ID="12345678-1234-1234-1234-1234567890ab"
export APPSTORE_API_KEY="$(base64 -i /path/to/AuthKey_ABCDEF1234.p8)"

# Optional but recommended: re-sign with your Mac App Distribution cert
export APPSTORE_DISTRIBUTION_IDENTITY="Apple Distribution: LunaOS Inc (XXXXXXXXXX)"
export APPSTORE_INSTALLER_IDENTITY="3rd Party Mac Developer Installer: LunaOS Inc (XXXXXXXXXX)"
export APPSTORE_PROVISION_PROFILE="$(base64 -i /path/to/VibeVault_Mac_App_Store.provisionprofile)"

bash scripts/appstore-upload.sh
```

The script:

1. Builds the release `.app` bundle (`scripts/bundle-app.sh release`).
2. Re-signs helper binaries and the app with the distribution identity.
3. Embeds the provisioning profile.
4. Produces `build/VibeVault-<version>-<build>.pkg`.
5. Validates and uploads the package to App Store Connect via `xcrun altool`.

After upload, finish the submission in App Store Connect:

- Screenshots
- App preview / description
- Privacy nutrition label
- Export compliance
- Review information

## CI upload

Add these GitHub repository secrets:

| Secret | Value |
|--------|-------|
| `APPSTORE_API_KEY_ID` | Key ID from App Store Connect > Users and Access > Keys |
| `APPSTORE_API_ISSUER_ID` | Issuer ID from the same page |
| `APPSTORE_API_KEY` | Base64-encoded `.p8` private key |
| `APPSTORE_DISTRIBUTION_IDENTITY` | Full common name of your Mac App Distribution cert |
| `APPSTORE_INSTALLER_IDENTITY` | Full common name of your Mac Installer Distribution cert |
| `APPSTORE_PROVISION_PROFILE` | Base64-encoded `.provisionprofile` |

Trigger manually:

```bash
gh workflow run appstore.yml
```

Or push a tag matching `v*`:

```bash
git tag v0.1.0
git push origin v0.1.0
```

## Troubleshooting

- `ITMS-90236`: missing or invalid provisioning profile → check `APPSTORE_PROVISION_PROFILE` and bundle ID.
- `ITMS-90238`: invalid signature → ensure all nested binaries and the app bundle are signed with the same distribution identity.
- `altool` API errors → verify the API key has **App Manager** or **Admin** role and the issuer/key IDs are correct.
- For local debugging without uploading, run `scripts/bundle-app.sh release` and inspect `build/VibeVault.app`.
