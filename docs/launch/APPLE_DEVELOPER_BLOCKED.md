# Apple Developer Enrollment Blocked

Date: July 20, 2026

## What This Blocks

Apple-issued signing certificates require Apple Developer Program membership.
Developer ID distribution for software downloaded outside the Mac App Store
requires a Developer ID certificate and Apple notarization before the app can be
promoted as Gatekeeper-safe.

Official references:

- Apple certificate support: https://developer.apple.com/support/certificates/
- Developer ID support: https://developer.apple.com/support/developer-id/
- Developer ID certificate docs: https://developer.apple.com/help/account/certificates/create-developer-id-certificates/

## Decision

Do not promote the unnotarized DMG to first-time users.

Launch Vibe Vault CLI-first until Apple Developer Program enrollment is solved.
The source-visible CLI, VaultCore package, MCP server, scanner, git guard,
browser host, launch docs, and threat model are enough for a technical launch.

## Safe Public Install Path

Use:

```bash
git clone https://github.com/lunaos-ai/luna-vault
cd luna-vault
swift build -c release --product vibevault
swift build -c release --product vibevault-mcp
.build/release/vibevault scan
```

After Homebrew tap verification:

```bash
brew tap finsavvyai/tap
brew install vibevault
vibevault scan
```

## What Not To Do

- Do not ask security-minded users to right-click-open or bypass Gatekeeper for
  the first public experience.
- Do not call the app "notarized" or "Gatekeeper-safe" until `spctl` and
  `stapler` pass.
- Do not make Product Hunt the first launch while the native app is blocked.
- Do not use a third party's Apple Developer account unless ownership,
  certificate custody, tax/legal identity, and repo/release authority are
  explicitly settled.

## How To Resolve Apple

1. Try enrollment from the Apple Developer app using an Apple Account with
   two-factor authentication enabled.
2. Use legal first and last name exactly as identity documents show.
3. For an organization, ensure legal entity name, D-U-N-S record, public
   website, phone, and authority to bind the organization all match.
4. If enrollment fails, contact Apple Developer Support and keep the Enrollment
   ID / Order ID if available.
5. Once membership is active, create Developer ID Application and Installer
   certificates, rebuild, notarize, staple, and verify.

## App Launch Gate

```bash
NOTARIZE=1 NOTARIZE_DMG=1 bash scripts/release.sh release
xcrun stapler validate build/VibeVault.dmg
spctl -a -vv -t open build/VibeVault.dmg
spctl -a -vv build/VibeVault.app
```

Only after these pass should the website make the native DMG the primary
install path.
