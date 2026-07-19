# vibe-vault

Secure credential access for AI coding agents on macOS. Lives in your menu bar.

[![macOS 14+](https://img.shields.io/badge/macOS-14%2B-black)](https://vibevault.lunaos.ai/)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Version](https://img.shields.io/badge/version-0.1.0-indigo)](CHANGELOG.md)

```bash
# instead of this:
export CF_API_TOKEN=$(op read "op://Personal/Cloudflare/api token")
npm run dev

# do this:
vibevault run -- npm run dev
```

Secrets live in macOS Keychain. Every read is audited per AI agent (Claude Code, Cursor, Devin). One command syncs to Cloudflare, Vercel, PushCI.

## Install

**App (menu bar)**

- https://vibevault.lunaos.ai/download
- Pitch page: https://vibevault.lunaos.ai/

**CLI**

```bash
brew tap luna-os/tap && brew install vibevault
# or from this repo: brew install --formula ./dist/homebrew/vibevault.rb
# or: bash scripts/install.sh
```

**Wire Cursor in one shot**

```bash
vibevault cursor prepare
```

## Quick start

```bash
vibevault add CF_API_TOKEN
cd ~/my-cloudflare-worker
vibevault scan
vibevault run -- npm run dev
vibevault push --to cloudflare --scope account_id=… --scope script_name=…
```

## Why

Vibe-coding workflows leak secrets through `.env` files and copy-paste into AI chats. 1Password / Doppler store secrets but don't know **which agent** read them, don't scan repos, and often need a cloud account.

## Differentiators

1. **AI-agent audit log** — `cursor read CF_API_TOKEN at 14:32 in repo my-worker`
2. **Auto-detect** — `wrangler.toml`, `vercel.json`, `.env*`, `package.json`
3. **Local-first** — Keychain only; sync is opt-in
4. **MCP + Cursor rules** — `vibevault cursor prepare`
5. **Team license** — Lemon Squeezy checkout + signed offline license (`vibevault license`)

## Architecture

```
vibe-vault/
├── apps/VibeVaultApp/        # SwiftUI menu bar + main window
├── packages/VaultCore/       # Keychain, Audit, Providers, Scanner, License
├── cli/vibevault/            # Swift CLI
├── cli/vibevault-mcp/        # MCP server
├── skills/vibevault/         # Agent skill
├── marketing/landing/        # GTM pitch page
├── docs/launch/              # Show HN / social pack
├── dist/lemonsqueezy/        # Checkout config + webhook notes
└── dist/homebrew/            # Homebrew formula
```

```bash
vibevault mcp install --client all
vibevault skill install
vibevault cursor prepare
vibevault cursor shadow
vibevault scan --git-only
vibevault guard install
vibevault sync status
vibevault sync push --to icloud
vibevault sync pull --from icloud --overwrite
vibevault license status
```

- Launch copy: `docs/launch/LAUNCH_PACK.md`
- Threat model: `docs/security/THREAT_MODEL.md`
- GTM plan: `.luna/vibe-vault/gtm/plan.md`
- Team licensing: `dist/lemonsqueezy/WEBHOOK.md`

## Build

### CLI

```bash
swift build -c release
.build/release/vibevault --help
```

### App

```bash
bash scripts/bundle-app.sh debug
open build/VibeVault.app
```

### Release DMG + website

```bash
bash scripts/release.sh
NOTARIZE=1 NOTARIZE_DMG=1 bash scripts/release.sh   # needs Apple creds
bash scripts/publish-to-website.sh
bash scripts/gtm-check.sh
bash scripts/publish-all.sh --dry-run
bash scripts/publish-all.sh --yes --tag v0.1.0
```

### Encrypted cloud sync

Vibe Vault can move a vault between Macs through iCloud Drive without putting plaintext secrets in iCloud.

```bash
# Mac A: write encrypted sync bundle to iCloud Drive
vibevault sync push --to icloud

# Mac B: import it after iCloud Drive syncs the file
vibevault sync pull --from icloud --overwrite
```

The sync bundle is written to `~/Library/Mobile Documents/com~apple~CloudDocs/Documents/VibeVault/Sync/vault.vvsync` and is encrypted with a sync passphrase. For automation, use `--passphrase-env VIBEVAULT_SYNC_PASSPHRASE` or `--passphrase-stdin`.

The macOS app also exposes this in **Settings -> Cloud Sync** with secure passphrase fields and explicit sync/import buttons.

### Browser extension

```bash
bash scripts/package-browser-extension.sh
swift build --product vibevault-browser-host
vibevault browser install --browser chrome --extension-id <extension-id>
```

The Chrome Web Store upload zip is `build/VibeVault-Browser-Importer.zip`. Store copy, privacy text, review notes, and screenshots live in `extensions/browser-vibevault/store/`.

## License

MIT for CLI + VaultCore + MCP (`LICENSE`). App binary branding may remain LunaOS proprietary — see LICENSE scope notes.

## Status

**v0.1.0** — see `CHANGELOG.md`.
