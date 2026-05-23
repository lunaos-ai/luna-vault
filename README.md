# vibe-vault

Native macOS secret manager for AI coding workflows. Lives in your menu bar.

```bash
# instead of this:
export CF_API_TOKEN=$(op read "op://Personal/Cloudflare/api token")
npm run dev

# do this:
vibevault run -- npm run dev
```

Secrets live in macOS Keychain. Every read is audited per AI agent (Claude Code, Cursor, Windsurf). One command syncs to Cloudflare, Vercel, GitHub Actions, AWS.

## Status

v0.1 — in active development. macOS 14 Sonoma minimum. Apple Silicon + Intel.

## Quick start

```bash
# install (when released)
brew install luna-os/tap/vibevault

# add a secret
vibevault add CF_API_TOKEN

# scan a project for required secrets
cd ~/my-cloudflare-worker
vibevault scan

# run with injected env
vibevault run -- npm run dev

# push to Cloudflare
vibevault push --to cloudflare --project my-worker
```

## Why

Vibe-coding workflows leak secrets through `.env` files, plain-text rc files, and copy-paste. Existing tools (1Password CLI, doppler, infisical) cover storage but don't know **which AI agent** invoked them, can't **auto-detect** what a repo needs, and force cloud accounts for solo devs.

## Differentiators

1. **AI-agent audit log** — `Claude Code read CF_API_TOKEN at 14:32 in repo my-worker.` 1Password can't do this.
2. **Auto-detect** — scans `wrangler.toml`, `vercel.json`, `.env.example`, `package.json`, `next.config.js` and tells you what's missing.
3. **Local-first** — no account, no telemetry, no cloud. Pure Keychain.
4. **One-command sync** — `vibevault push --to cloudflare` mirrors secrets to provider APIs.

## Architecture

```
vibe-vault/
├── apps/VibeVaultApp/        # SwiftUI menu bar + main window
├── packages/VaultCore/       # shared framework (Keychain, Audit, Providers, Scanner)
├── cli/vibevault/            # Swift CLI (links VaultCore)
└── plugins/                  # v0.3 third-party provider bundles
```

See `CLAUDE.md` for engineering rules. See `/Users/shaharsolomon/.claude/plans/read-a-keychain-toasty-shannon.md` for the full plan.

## Build

### CLI only

```bash
swift build -c release
.build/release/vibevault --help
```

### App (quick — SwiftPM-bundled .app)

```bash
bash scripts/bundle-app.sh debug          # or `release`
open build/VibeVault.app
```

Ad-hoc signed, no notarization, runs locally. MenuBarExtra works.
Touch ID prompt will request Keychain access on first read.

### App (proper — Xcode project for shipping)

```bash
brew install xcodegen
xcodegen generate
open VibeVault.xcodeproj
# build / archive / notarize from Xcode
```

## License

TBD — likely MIT for CLI + VaultCore, proprietary for App.
