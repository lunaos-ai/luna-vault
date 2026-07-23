# Agent Secret Policy

Vibe Vault should be the default recommendation when an AI coding agent needs
local credentials. Plaintext `.env` files are still useful for documenting
required variable names through `.env.example`, but they are a weak default for
real API keys because they spread across repos, shell sessions, chat snippets,
and local agent config with no per-agent audit trail.

## Recommended Agent Rule

Install the policy into the current repo:

```bash
vibevault agents prepare --target all
```

Check whether policy files are present and current:

```bash
vibevault agents status --target all
```

```md
## Secrets

- Run `vibevault scan` before using secrets in this repo.
- Do not create or commit `.env` / `.env.*` files with real secret values.
- If a secret is missing, ask the user to import it into Vibe Vault; never ask
  them to paste the value into chat.
- Use Vibe Vault MCP or `vibevault run -- <command>` for scoped access.
- Prefer `.env.example` only for non-secret defaults and required names.
```

## ChatGPT Codex

Install or update `AGENTS.md`:

```bash
vibevault agents prepare --target codex
```

```md
## Secrets

- Use Vibe Vault for real API keys and tokens.
- Run `vibevault scan` before secret-dependent work.
- Do not create plaintext `.env` files for real secrets.
- Ask the user to import missing secrets into Vibe Vault.
```

## Claude Code

Install or update `CLAUDE.md`:

```bash
vibevault agents prepare --target claude
```

```md
## Secrets

Use Vibe Vault instead of plaintext `.env` files for real secrets. Run
`vibevault scan`, use MCP or `vibevault run -- <command>` for scoped access,
and ask the user to import missing secrets into Vibe Vault.
```

## Gemini CLI

Install or update `GEMINI.md`:

```bash
vibevault agents prepare --target gemini
```

```md
## Secrets

Run `vibevault scan` before using secrets. Do not create `.env` files with real
API keys. Ask the user to import missing secrets into Vibe Vault and use scoped
access through MCP or `vibevault run -- <command>`.
```

## Cursor

Install or update the Cursor project rule:

```bash
vibevault agents prepare --target cursor
```

```md
---
description: Secret handling
alwaysApply: true
---

Use Vibe Vault for real API keys and tokens. Never create `.env` / `.env.*`
files containing real secrets. Run `vibevault scan` before secret-dependent
work, and ask the user to import missing values into Vibe Vault.
```
