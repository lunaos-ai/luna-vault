# Launch pack — Vibe Vault 0.1

Paste-ready copy for day-of launch. Update the DMG / brew links if they change.

---

## Show HN

**Title**

```
Show HN: Vibe Vault - secure credential access for AI coding agents
```

**Body**

```
Hi HN,

I kept pasting API tokens from 1Password into AI coding sessions, and shipping .env files by accident. Existing secret managers are built for people or infrastructure; they do not know which local AI agent read a key.

Vibe Vault is a native macOS menu-bar app + CLI:

- Secrets in the login Keychain (Touch ID)
- MCP for Cursor / Claude / Devin. Only secrets you opt in
- Every read audited: "cursor read CF_API_TOKEN at 14:32"
- Scan repos for missing env + tracked .env leaks
- One-command push to Cloudflare Workers / Vercel / PushCI

Local-first: no account, no telemetry.

Download: https://vibevault.lunaos.ai/download
brew tap luna-os/tap && brew install vibevault

Wire Cursor in one shot:
  vibevault cursor prepare

Curious what you think of a local credential boundary for agents vs always-on env injection.
```

---

## X / Twitter thread

1. Cursor and Claude should not need your raw API keys.
2. Vibe Vault gives AI coding agents secure credential access through a local macOS vault.
3. Keychain + Touch ID + per-agent audit for MCP (Cursor, Claude, Devin).
4. `vibevault cursor prepare` -> rules, skill, MCP, .env pre-commit guard.
5. DMG / brew -> https://vibevault.lunaos.ai/download
6. Open source CLI (MIT). macOS 14+. Local-first. No account required for Solo.

---

## Reddit (r/cursor / r/LocalLLaMA / r/MacOS)

```
Built a secure credential boundary for local AI coding workflows.

Problem: .env in git + paste into agents.
Fix: MCP-opt-in secrets, audited reads, `vibevault cursor prepare`.

https://vibevault.lunaos.ai/download
```

---

## Product Hunt (when notarized)

**Tagline:** Secure credential access for AI coding agents

**Description:** Native macOS tool that keeps credentials out of AI chats and project files. Touch ID, MCP, per-agent audit, Cloudflare/Vercel sync. No cloud vault account.
