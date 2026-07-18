# Launch pack — Vibe Vault 0.1

Paste-ready copy for day-of launch. Update the DMG / brew links if they change.

---

## Show HN

**Title**

```
Show HN: Vibe Vault – local Keychain secrets with per-agent audit for Cursor
```

**Body**

```
Hi HN,

I kept pasting API tokens from 1Password into Cursor/Claude chat, and shipping .env files by accident. Existing secret managers don't know which AI agent read a key.

Vibe Vault is a native macOS menu-bar app + CLI:

- Secrets in the login Keychain (Touch ID)
- MCP for Cursor / Claude / Windsurf — only secrets you opt in
- Every read audited: "cursor read CF_API_TOKEN at 14:32"
- Scan repos for missing env + tracked .env leaks
- One-command push to Cloudflare Workers / Vercel / PushCI

Local-first: no account, no telemetry.

Download: https://vibevault.lunaos.ai/download
brew tap luna-os/tap && brew install vibevault

Wire Cursor in one shot:
  vibevault cursor prepare

Curious what you think of the MCP-allowed gate vs always-on agent env injectors.
```

---

## X / Twitter thread

1. Stop pasting secrets into Cursor chat.
2. Vibe Vault: Keychain + Touch ID + per-agent audit for MCP (Cursor, Claude, Windsurf).
3. `vibevault cursor prepare` → rules, skill, MCP, .env pre-commit guard.
4. DMG / brew -> https://vibevault.lunaos.ai/download
5. Open source CLI (MIT). macOS 14+. Local-first.

---

## Reddit (r/cursor / r/LocalLLaMA / r/MacOS)

```
Built a local Keychain secret manager aimed at AI coding workflows.

Problem: .env in git + paste into agents.
Fix: MCP-opt-in secrets, audited reads, `vibevault cursor prepare`.

https://vibevault.lunaos.ai/download
```

---

## Product Hunt (when notarized)

**Tagline:** Local Keychain secrets with AI-agent audit for Cursor

**Description:** Native macOS tool that stops copy-paste of secrets into AI chats. Touch ID, MCP, Cloudflare/Vercel sync. No cloud vault account.
