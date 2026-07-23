# AI Agent Marketing Blitz - Vibe Vault

Date: July 22, 2026

Primary campaign URL: https://vibevault.lunaos.ai/agents  
Install URL: https://vibevault.lunaos.ai/download  
Scanner URL: https://vibevault.lunaos.ai/scan  
Security URL: https://vibevault.lunaos.ai/security
Alternatives URL: https://vibevault.lunaos.ai/alternatives
Chrome Web Store: https://chromewebstore.google.com/detail/vibe-vault-importer/nfeigikipagiccmhlolgfbeienkckbpc

## Current Launch Mode

Homebrew-first CLI launch. Lead with the verified Homebrew install path while
the notarized DMG is blocked. Chrome extension copy can now say the importer is
live in the Chrome Web Store.

Do not promote the unnotarized DMG.

## Order Today

1. Post to one high-signal AI coding community first: Cursor, Claude Code, or
   LocalLLaMA.
2. Wait for install friction feedback for 2-4 hours.
3. Post the X/Twitter technical thread.
4. Post Show HN only if no source-install blocker appears.
5. Use direct outreach to Cursor/Claude users with the `/agents` page.
6. Hold Product Hunt until native install trust is clean.

## Positioning

Vibe Vault is the local credential boundary for AI coding agents.

Use this language:

- "credential boundary for AI coding agents"
- "local MCP credential access"
- "agent reads are permissioned and audited"
- "keeps raw API keys out of prompts, `.env`, shell history, and notes"
- "Homebrew-first while notarized native distribution is pending"
- "Chrome Web Store importer is live for saving newly generated provider keys"
- "comparison pages explain where Vibe Vault fits next to 1Password, Bitwarden, Doppler, Infisical, and .env"

Avoid this language:

- "password manager replacement"
- "cloud vault"
- "prevents all leaks"
- "download the Mac app" until notarized

## Cursor / Claude Community Post

```text
Built a local credential boundary for Cursor and Claude Code.

The problem I kept hitting: agents can now work inside real repos and terminals,
but credentials still move through .env files, shell exports, password-manager
copy-paste, or pasted chat snippets.

Vibe Vault gives local AI coding agents a narrower path:

- encrypted local macOS vault
- MCP setup for Cursor / Claude Code / local tools
- repo scanner and .env git guard
- explicit local approval for named credentials
- per-agent audit log
- Chrome Web Store importer for newly generated provider keys
- Homebrew-first CLI install while notarized app distribution is pending

Agent-focused page:
https://vibevault.lunaos.ai/agents

Install:
https://vibevault.lunaos.ai/download

I am looking for feedback from people using agents on production-adjacent repos:
would you prefer scoped credential reads through a local runtime, or broad env
injection for the whole session?
```

## LocalLLaMA / Local Agents Post

```text
Local-first secret access for AI coding agents on macOS.

Vibe Vault is a local vault + CLI + MCP server for workflows where agents need
credentials but raw keys should not be pasted into prompts, shell history, or
project files.

The core idea: credential access should become a runtime boundary, not just an
environment variable.

Included today:

- local encrypted storage with Keychain-held master key
- MCP for local coding agents
- repo scanner for expected env names and tracked secret-bearing files
- git guard for .env / MCP / local agent settings
- per-agent audit log
- optional encrypted sync bundles between Macs
- Chrome Web Store importer for saving newly generated provider keys

https://vibevault.lunaos.ai/agents
```

## X / Twitter Thread

```text
1/ AI coding agents should not need raw API keys pasted into chat.

I built Vibe Vault: a local credential boundary for Cursor, Claude Code, Devin,
VS Code, and terminal agents.

https://vibevault.lunaos.ai/agents
```

```text
2/ The old local-dev pattern breaks down with agents:

- .env files copied between repos
- shell exports with broad session access
- password-manager copy-paste
- keys pasted into prompts or notes
- no answer to "which agent read this?"
```

```text
3/ Vibe Vault gives agents a narrower path:

- local macOS vault
- Keychain-held master key
- MCP setup
- repo scanner
- .env git guard
- named credential reads
- per-agent audit
- browser importer for newly generated provider keys
```

```text
4/ Start with one repo:

vibevault scan
vibevault guard install
vibevault cursor prepare

Then the agent requests named credentials through the local vault boundary.
```

```text
5/ Homebrew install is live now while notarized app distribution is pending:

https://vibevault.lunaos.ai/download

Security model:
https://vibevault.lunaos.ai/security

Alternatives:
https://vibevault.lunaos.ai/alternatives
```

## Show HN

Title:

```text
Show HN: Vibe Vault - local credential access for AI coding agents
```

URL:

```text
https://vibevault.lunaos.ai/agents
```

First comment:

```text
Hi HN,

I built Vibe Vault because my AI coding workflow had a weak spot: Cursor and
Claude Code were operating directly inside repos and terminals, but production
API keys were still moving through .env files, shell exports, password-manager
copy-paste, and occasionally chat.

Vibe Vault is a local macOS vault + CLI + MCP server for AI-coding credentials.

What it does:

- stores secrets in an encrypted local vault with the master key in macOS Keychain
- scans repos for expected env names and tracked secret-bearing files
- installs MCP, agent rules, skills, ignore rules, and a git guard
- lets agents request named credentials instead of receiving a pasted vault dump
- records agent/project/secret/action/result/time for reads
- supports optional encrypted sync bundles between Macs
- includes a Chrome Web Store importer for newly generated provider keys

The install path is Homebrew-first right now because I am not promoting an
unnotarized DMG for a security tool:

  brew tap finsavvyai/tap
  brew install vibevault
  vibevault scan

I am looking for critique on the boundary. Should local coding agents receive
scoped credential reads through a runtime, or is broad env injection still the
right default?
```

## Direct Outreach

```text
Hey <name>,

I launched a narrow local security tool for AI coding workflows and thought of
you because you use Cursor/Claude against real repos.

Vibe Vault is a local macOS vault + CLI + MCP server. It keeps raw API keys out
of prompts, .env files, and shell history by letting agents request named
credentials through an audited local boundary.

Agent page:
https://vibevault.lunaos.ai/agents

Install:
https://vibevault.lunaos.ai/download

I am looking for install friction and security-model pushback, not praise.
```

## Directory / Listing Targets

- Cursor community / forum
- Claude Code community channels
- LocalLLaMA
- Hacker News
- GitHub README / topics after repository visibility is settled
- MCP directories once install path is clean
- Chrome Web Store listing is live; link it from launch posts where relevant
- Product Hunt after native install trust is fixed

## SEO Pages To Add Next

1. `/cursor-secrets` - Cursor API key security and MCP credential access.
2. `/claude-code-secrets` - Claude Code local settings and secret exposure.
3. `/mcp-secrets` - MCP credential access patterns and local vault boundaries.
4. `/env-file-security` - `.env` risks in AI-assisted development.
5. `/agent-audit-log` - tracking local agent credential reads.
