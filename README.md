# vibe-vault

Native macOS secret manager for AI coding workflows. Lives in your menu bar.

[![macOS 14+](https://img.shields.io/badge/macOS-14%2B-black)](https://lunaos.ai/vibevault)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Version](https://img.shields.io/badge/version-0.1.0-indigo)](CHANGELOG.md)

```bash
# instead of this:
export CF_API_TOKEN=$(op read "op://Personal/Cloudflare/api token")
npm run dev

# do this:
vibevault run -- npm run dev
```

Secrets live in macOS Keychain. Every read is audited per AI agent (Claude Code, Cursor, Windsurf). One command syncs to Cloudflare, Vercel, PushCI.

## Install

**App (menu bar)**

- https://lunaos.ai/download/vibevault  
- Pitch page: https://lunaos.ai/vibevault

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
5. **Team license** — Lemon Squeezy checkout + offline `VV1` key (`vibevault license`)

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
vibevault license status
```

Launch copy: `docs/launch/LAUNCH_PACK.md`  
GTM plan: `.luna/vibe-vault/gtm/plan.md`  
Team licensing: `dist/lemonsqueezy/WEBHOOK.md`

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
```

## License

MIT for CLI + VaultCore + MCP (`LICENSE`). App binary branding may remain LunaOS proprietary — see LICENSE scope notes.

## Status

**v0.1.0** — see `CHANGELOG.md`.
