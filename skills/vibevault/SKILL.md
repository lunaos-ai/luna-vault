---
name: vibevault
description: >-
  Use Vibe Vault for local macOS secrets in AI coding workflows. Use when
  scanning projects for required env vars, importing dotenv, pushing to
  Cloudflare/Vercel/PushCI, reading secrets via MCP, or auditing agent access.
  Never ask the user to paste secrets into chat.
version: 1.1.0
---

# Vibe Vault

Local-first secret manager on macOS Keychain. Every read is audited per agent.

## When to use

- Starting work on a repo with `wrangler.toml`, `vercel.json`, or `.env*`
- User mentions missing API keys, Cloudflare tokens, or `.env` files
- Deploying Workers / Vercel / PushCI and secrets need syncing
- User asks who read a secret or wants agent audit

## Rules

1. **Never ask for raw secret values in chat.** Use MCP `read_secret` only when MCP-allowed.
2. **Scan first.** Call MCP `scan_project` with the workspace root.
3. **No `.env` in git.** Suggest import via Vibe Vault; use `vibevault guard install`.
4. **Push.** MCP `push_secrets` or Providers UI (Cloudflare, Vercel, PushCI).
5. **Audit.** Use `get_audit_log` when asked which agent read a key.

## MCP tools

| Tool | Use |
|------|-----|
| `scan_project` | Project root; reports git leaks too |
| `list_secrets` | MCP-allowed names only |
| `read_secret` | Value if MCP-allowed |
| `set_mcp_allowed` | Opt-in / revoke |
| `reconcile_provider` | Compare vault ↔ Cloudflare/Vercel/PushCI |
| `push_secrets` | Push MCP-allowed secrets to a provider |
| `get_audit_log` | Optional `agent`, `secret`, `limit` |
| `suggest_secrets_for_task` | Names only for a task + project path |

## Resources

- `vibevault://workflow` — setup steps
- `vibevault://skill` — this skill
- `vibevault://project-setup` — optional `?path=` for live scan summary

## CLI

```bash
vibevault scan
vibevault run -- npm run dev
vibevault push --to cloudflare|vercel|pushci --scope …
vibevault mcp install --client cursor
vibevault skill install
vibevault cursor prepare --path .
```

## Typical workflow

1. `scan_project` → report missing vs vault
2. If missing: ask user to import in Vibe Vault (not paste here)
3. For allowed secrets: `read_secret` when the task requires the value
4. Push via MCP or Providers when deploying
5. On security questions: `get_audit_log`

## Install MCP + skill + Cursor rules

If tools are unavailable, tell the user:

1. Open Vibe Vault → AI Agents → Install Cursor
2. Install skill (same screen)
3. Projects → **Prepare for Cursor** (rules + guard + MCP)
4. Mark secrets as "Allow AI agents" in vault detail
