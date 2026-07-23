# Community Posts - Vibe Vault 0.1

Use these after the Level 0 gates in `docs/launch/GTM_RUNBOOK.md` pass.

## Cursor Community

```text
Built a local credential vault for Cursor workflows.

The pain: Cursor can now operate directly in real repos and terminals, but API
keys still move through .env files, shell exports, and copy-paste from password
managers.

Vibe Vault gives Cursor a local MCP credential boundary:

- encrypted local vault, master key in macOS Keychain
- Touch ID/session-gated reads
- `vibevault cursor prepare` for MCP, rules, skills, ignore rules, and git guard
- per-agent audit log
- provider sync to Cloudflare/Vercel/PushCI
- browser import for newly generated provider keys
- random secret generation in the app

Download:
https://vibevault.lunaos.ai/download

I am looking for feedback from people using Cursor against production-adjacent
repos. What would make the permission/audit flow feel trustworthy without
getting in the way?
```

## Claude Code Community

```text
I built Vibe Vault for local AI coding sessions where Claude Code needs a secret
but I do not want to paste raw API keys into chat, shell history, or project
files.

It is a macOS app + CLI + MCP server:

- encrypted local vault
- master key in macOS Keychain
- Touch ID/session gated reads
- MCP access for Claude Code and other agents
- per-agent audit trail
- repo scan and .env guard
- explicit provider sync

https://vibevault.lunaos.ai/

The core design question: should agent credential reads be explicit and audited,
or is broad env injection good enough for most local AI coding?
```

## LocalLLaMA

```text
Local-first credential access for AI coding agents on macOS.

Vibe Vault is not a hosted password manager. It is a local vault + CLI + MCP
server that lets local agents request credentials through an audited boundary
instead of copy-paste or always-on env vars.

What is included:

- encrypted local storage with Keychain-held master key
- Touch ID/session gated reads
- MCP for Cursor/Claude/Devin/VS Code
- audit log by agent/project/secret/action/time
- repo scanner and .env git guard
- provider sync when explicitly requested
- optional encrypted sync between Macs

https://vibevault.lunaos.ai/

I would especially like feedback from people running local or semi-local agents
against real repos: where should this boundary live?
```

## Indie Hackers / Dev Tool Twitter

```text
Launched Vibe Vault.

It is a local macOS credential vault for AI coding agents.

The goal: Cursor/Claude can use the keys they need without raw API keys ending
up in chat, .env files, shell history, or notes.

https://vibevault.lunaos.ai/
```

```text
What makes it different from a normal password manager:

- MCP for AI coding tools
- per-agent audit
- repo scanner
- .env git guard
- provider sync
- browser import for newly generated keys
- local random key generator
- optional encrypted sync between Macs
```

## Security Twitter / LinkedIn

```text
AI coding agents changed the local credential threat model.

Agents now run commands, inspect repos, and touch deployment workflows, while
secrets still move through .env files and copy-paste.

Vibe Vault creates a local credential boundary for that workflow:
permissioned reads, Touch ID/session approval, and per-agent audit.

https://vibevault.lunaos.ai/
```

## Direct Outreach

```text
Hey <name>,

I launched a small security/devtool for AI coding workflows and thought of you
because you use Cursor/Claude against real projects.

Vibe Vault is a local macOS vault + CLI + MCP server. It keeps API keys out of
AI chat and .env files by letting agents request secrets through a local,
audited boundary.

Download:
https://vibevault.lunaos.ai/download

I am not looking for praise. I am looking for install friction, confusing copy,
or places where the security model does not match how you work.
```
