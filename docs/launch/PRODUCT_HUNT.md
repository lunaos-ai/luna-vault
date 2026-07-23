# Product Hunt Plan - Vibe Vault 0.1

Product Hunt should happen after the technical launch, not before it.

## Go / No-Go

Go only if:

- DMG is notarized and Gatekeeper-safe.
- Homebrew or source install path is verified.
- Chrome extension status is clean or omitted from copy.
- One browser import demo is recorded.
- Website, download, checkout, and privacy pages are live.
- The most common HN/community objections have been addressed in README/FAQ.

## Listing

**Name**

```text
Vibe Vault
```

**Tagline**

```text
Secure credential access for AI coding agents
```

**Short description**

```text
Keep API keys out of AI chats, .env files, and shell history. Vibe Vault gives
Cursor, Claude Code, Devin, VS Code, and local terminal workflows permissioned
access through an encrypted macOS vault with Touch ID, MCP, audit, provider
sync, browser import, key generation, and optional encrypted Mac-to-Mac sync.
```

**Topics**

```text
Developer Tools
Security
Artificial Intelligence
Productivity
Mac
```

## Gallery Assets

Required:

- Hero image: problem/solution in one screenshot.
- App screenshot: vault list + detail/audit context.
- Browser importer screenshot: provider key save panel.
- Terminal screenshot: `vibevault cursor prepare` and `vibevault audit`.
- 60-90 second demo video.

## Maker Comment

```text
I built Vibe Vault because AI coding agents changed my local secret-handling
workflow before my tools caught up.

Cursor, Claude Code, Devin, and terminal agents can now run commands, inspect
repos, and touch deployment systems. But API keys are still usually moved around
with .env files, shell exports, password-manager copy-paste, and chat messages.

Vibe Vault creates a local credential boundary:

- encrypted macOS vault with the master key in Keychain
- Touch ID/session-gated reads
- MCP access for AI coding agents
- per-agent audit log
- repo scanning and .env git guard
- browser import for newly generated provider keys
- provider sync only when explicitly requested
- local random key generation
- optional encrypted sync between Macs

Solo use is local-first: no account, no telemetry, no hosted cloud vault.

The goal is not to replace your password manager. The goal is to give AI coding
agents a safer way to use credentials during development.
```

## Launch Day Timeline

00:01 PT:

- Product goes live.
- Maker comment posted.
- Website checked.
- Download checked.

Morning:

- Reply to every technical comment.
- Post on X/LinkedIn with a demo clip.
- Message the private smoke group with the PH link.

Midday:

- Publish one technical thread: "Why env vars are the wrong default boundary for AI agents."
- Share in communities only where prior participation exists.

Evening:

- Post a transparent update: top feedback, fixes shipped, next provider support.

## Product Hunt Reply Bank

**How is this different from 1Password?**

1Password is a strong human vault. Vibe Vault is the local runtime around AI
coding credentials: MCP setup, permissioned reads, repo scan, audit, provider
sync, browser import, and command injection.

**Does this store secrets in the cloud?**

No hosted cloud vault for Solo. Secrets live locally. Optional sync creates an
encrypted bundle that you can move through iCloud Drive or another storage path.

**What happens after an agent receives a key?**

Vibe Vault cannot control a process after an approved read. It reduces exposure,
adds gating, and records access so the read is visible after the session.

**Is it open source?**

The CLI, VaultCore, MCP server, skills, and plugin manifests are source-visible
under the repo license. App binary branding may remain LunaOS proprietary based
on the license scope.
