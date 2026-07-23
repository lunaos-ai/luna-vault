# Launch Pack - Vibe Vault 0.1

Paste-ready copy for launch. Current mode is CLI-first because Developer ID
notarization is blocked by Apple Developer Program enrollment. Do not promote
the unnotarized DMG to first-time users.

Primary URL: https://vibevault.lunaos.ai/
Install URL: https://vibevault.lunaos.ai/download

---

## Core Positioning

**One-line**

Secure credential access for AI coding agents.

**Short**

Vibe Vault is a local macOS vault, CLI, and MCP server that lets Cursor,
Claude Code, Devin, VS Code, and terminal workflows access credentials without
pasting raw API keys into chat, `.env` files, or shell history.

**Long**

AI coding agents now operate inside terminals, repositories, and deployment
workflows. Secrets are still handled with copy-paste, `.env` files, and broad
environment injection. Vibe Vault creates a local credential boundary: encrypted
local storage, master key in macOS Keychain, Touch ID gated reads, per-agent
audit, repo scanning, provider sync, optional encrypted Mac-to-Mac sync, browser
import, and local random key generation.

---

## Show HN

**Title**

```text
Show HN: Vibe Vault - local credential access for AI coding agents
```

**Submission URL**

```text
https://vibevault.lunaos.ai/
```

**First comment**

```text
Hi HN,

I built Vibe Vault after noticing that my AI coding workflow had a weak spot:
I was still moving production API keys around with copy-paste, .env files, and
shell exports, even though Cursor and Claude Code were now operating directly
inside my repos and terminals.

Vibe Vault is a native macOS app + CLI + MCP server for local AI-coding
credentials.

What it does:

- Stores secrets in an encrypted local vault with the master key in macOS Keychain
- Gates reads locally with Touch ID/session approval
- Lets Cursor, Claude Code, Devin, VS Code, and terminal commands request secrets through MCP/CLI instead of chat paste
- Records audited reads: agent, project, secret name, action, result, timestamp
- Scans repos for missing env names and tracked .env leaks
- Pushes selected secrets to Cloudflare, Vercel, and PushCI only when requested
- Imports provider keys from supported browser dashboards through a Chrome extension/native host
- Generates new local secret values as Hex, Base64 URL, Base64, password, UUID, or prefixed tokens
- Supports optional encrypted sync bundles for moving a vault between Macs

Solo use is local-first: no account, no telemetry, and no hosted cloud vault.

Install from source:

  git clone https://github.com/lunaos-ai/luna-vault
  cd luna-vault
  swift build -c release --product vibevault
  swift build -c release --product vibevault-mcp
  .build/release/vibevault scan

Security architecture:

  https://vibevault.lunaos.ai/security

Prepare a Cursor repo:

  vibevault cursor prepare

I am especially interested in feedback on the boundary: should local AI agents
receive scoped credential reads through a vault/runtime, or should teams keep
leaning on always-on environment variables and password-manager copy-paste?
```

**When Homebrew is verified, replace the source install block with:**

```text
brew tap finsavvyai/tap && brew install vibevault
```

---

## X / Twitter Thread

```text
1/ AI coding agents should not need raw API keys pasted into chat.

I built Vibe Vault: secure credential access for Cursor, Claude Code, Devin,
VS Code, and local terminal workflows.

https://vibevault.lunaos.ai/
```

```text
2/ The problem:

AI agents now run commands, inspect repos, call tools, and touch deployment
workflows.

Secrets still move through .env files, shell history, notes, and copy-paste.
```

```text
3/ Vibe Vault gives agents a local credential boundary:

- encrypted local vault
- master key in macOS Keychain
- Touch ID gated reads
- MCP for Cursor/Claude/Devin
- per-agent audit log
- repo scan + .env guard
```

```text
4/ It also handles the day-to-day workflow:

- generate new keys locally
- import provider keys from supported browser dashboards
- push selected secrets to Cloudflare/Vercel/PushCI
- encrypted sync bundles for moving between Macs
```

```text
5/ Solo use is local-first:

No account.
No telemetry.
No hosted cloud vault.

Install:
https://vibevault.lunaos.ai/download

Source-first while Homebrew is being verified:
git clone https://github.com/lunaos-ai/luna-vault
cd luna-vault && swift build -c release --product vibevault
```

```text
6/ One command to prepare Cursor:

vibevault cursor prepare

That wires MCP, agent rules, skills, ignore rules, and git leak protection so
agents request secrets through the vault instead of copy-paste.
```

---

## Reddit / Cursor Community

**Title**

```text
Built a local credential vault for Cursor and Claude Code workflows
```

**Body**

```text
I built Vibe Vault because my AI coding workflow still had the same secret
handling problem: API keys in .env files, copy-paste from password managers,
and no clear audit trail for which local agent or command read a key.

Vibe Vault is a macOS app + CLI + MCP server:

- local encrypted vault, master key in Keychain
- Touch ID/session-gated reads
- Cursor / Claude Code / Devin / VS Code MCP setup
- per-agent audit log
- repo scanning and .env git guard
- provider sync to Cloudflare, Vercel, and PushCI
- browser importer for newly generated provider keys
- random key generation in common formats
- optional encrypted sync bundle for moving between Macs

Prepare a Cursor repo:

  vibevault cursor prepare

Download:
https://vibevault.lunaos.ai/download

I would like feedback from people using agents against real repos: would you use
a local permissioned read path, or do you prefer env injection/password-manager
copy-paste?
```

---

## LocalLLaMA

**Title**

```text
Local-first secret access for AI coding agents on macOS
```

**Body**

```text
I made Vibe Vault for local AI coding workflows where the model/agent needs
credentials but I do not want raw secrets pasted into prompts, shell history, or
project files.

It is not a hosted password manager. It is a local macOS vault + CLI + MCP
server:

- encrypted local vault with Keychain-held master key
- Touch ID gated reads
- MCP access for Cursor/Claude/Devin/VS Code
- per-agent audit log
- repo scanner and .env guard
- provider sync when explicitly requested
- optional encrypted sync bundle between Macs

The bigger question I am exploring: as local agents get more capable, should
credential access become a runtime boundary instead of an environment variable?

https://vibevault.lunaos.ai/
```

---

## Product Hunt

Use only after the install path is stable and native install trust is clean.

**Name**

```text
Vibe Vault
```

**Tagline**

```text
Secure credential access for AI coding agents
```

**Description**

```text
Vibe Vault is a local macOS app, CLI, and MCP server that keeps credentials out
of AI chats and project files. Give Cursor, Claude Code, Devin, VS Code, and
terminal workflows permissioned access through an encrypted local vault with
Touch ID gated reads, per-agent audit, repo scanning, provider sync, browser
import, local key generation, and optional encrypted sync between Macs.
```

**First maker comment**

```text
I built Vibe Vault after seeing a gap in AI coding workflows: agents can now run
commands, inspect repos, and touch deployment systems, but credentials are still
usually moved around with copy-paste, .env files, and broad shell injection.

Vibe Vault creates a local credential boundary for that workflow. Solo users do
not need an account or hosted cloud vault. Secrets stay in an encrypted local
vault, the master key stays in macOS Keychain, reads can be Touch ID gated, and
access is audited by agent/project/action/time.

The goal is simple: AI agents can use the keys they need without turning API
keys into chat messages, notes, shell history, or forgotten project files.
```

**Tags**

```text
Developer Tools
Security
Productivity
Artificial Intelligence
Mac
```

---

## Launch Email

**Subject**

```text
Vibe Vault: local credential access for AI coding agents
```

**Body**

```text
Hi,

I just launched Vibe Vault, a local macOS vault and CLI for AI-coding
credentials.

It is built for the workflow where Cursor, Claude Code, Devin, VS Code, or a
terminal command needs a key, but you do not want to paste raw credentials into
chat, .env files, shell history, or notes.

Highlights:

- encrypted local vault, master key in macOS Keychain
- Touch ID/session-gated reads
- MCP setup for AI coding agents
- per-agent audit log
- repo scanning and .env git guard
- provider sync to Cloudflare/Vercel/PushCI
- browser import for newly generated provider keys
- random key generation in common formats
- optional encrypted sync between Macs

Download:
https://vibevault.lunaos.ai/download

I would value blunt feedback, especially if you use AI agents against real
production repos.
```

---

## 90 Second Demo Script

```text
This is Vibe Vault: a local credential vault for AI coding agents.

First I scan a repo. Vibe Vault sees which env names the project expects and
whether risky .env files are tracked.

Then I add or generate a key. Values are stored in an encrypted local vault; the
master key lives in macOS Keychain.

Now I run `vibevault cursor prepare`. This wires MCP, agent rules, ignore rules,
skills, and a git leak guard into the project.

When Cursor or Claude Code needs a credential, it requests the value through
Vibe Vault. Reads can require Touch ID/session approval, and each access is
audited with agent, project, secret name, action, result, and timestamp.

If I rotate or create a provider key, I can import it through the browser
extension or push selected secrets to Cloudflare, Vercel, or PushCI.

Solo use stays local-first: no account, no telemetry, and no hosted cloud vault.
```

---

## Objection Responses

**Is this just 1Password for AI?**

No. Keep your password manager for human login and general secret storage. Vibe
Vault is the local runtime boundary for AI coding: MCP setup, repo scanning,
agent-aware reads, audit, provider sync, browser import, and command injection.

**Why not just use environment variables?**

Always-on environment variables are broad access. Vibe Vault makes the read
explicit, scoped to the workflow, and auditable after the session.

**Why not use HashiCorp Vault or Doppler?**

Those are strong infrastructure/cloud secret systems. Vibe Vault starts at the
local AI coding workflow: one Mac, one repo, one agent requesting a credential
through a local boundary.

**Does cloud sync make this a cloud vault?**

No. Sync is an optional encrypted bundle for moving between Macs. The product
does not become a hosted LunaOS cloud vault.

**Can malware still read secrets?**

No local secret manager can defend against complete device compromise. Vibe
Vault reduces copy-paste exposure, gates local reads, and records access; it is
not an anti-malware boundary.
