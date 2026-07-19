# Agent Layers — Implementation Plan

North star: every AI client (Cursor, VS Code, Devin, Claude Code) knows how to use Vibe Vault without the user pasting secrets into chat.

## Architecture

```
┌─────────────────────────────────────────────────────────┐
│  IDE Shells          VS Code ext · MCP config install   │
├─────────────────────────────────────────────────────────┤
│  Agent Skills        SKILL.md → ~/.cursor/skills/…     │
├─────────────────────────────────────────────────────────┤
│  Agent Bridge        vibevault-mcp · CLI · audit        │
├─────────────────────────────────────────────────────────┤
│  Providers           builtin + plugins/ manifests       │
├─────────────────────────────────────────────────────────┤
│  VaultCore           Keychain · audit · scanner         │
└─────────────────────────────────────────────────────────┘
```

## Layer 1 — AI Bridge (shipped)

| Component | Status |
|-----------|--------|
| `vibevault-mcp` stdio server | Done |
| Tools: list/read/scan/audit/set_mcp_allowed | Done |
| MCP client install (Cursor, VS Code, Devin, …) | Done |
| Agent attribution in audit log | Done |
| `vibevault mcp install\|status\|test` | Done |

## Layer 2 — Agent Skills (this sprint)

| Deliverable | Path |
|-------------|------|
| Canonical skill content | `skills/vibevault/SKILL.md` |
| Installer (VaultCore) | `AgentSkillInstaller.swift` |
| Install targets | Cursor, Claude Code, Claude Desktop, Devin |
| App UI | AI Agents → Install skill |
| CLI | `vibevault skill install\|status` |
| Onboarding | Quick install skill with MCP |

Skill teaches: scan before code, never ask for raw secrets, use MCP read only when allowed, push via Cloudflare sync.

## Layer 3 — MCP Resources & Prompts (this sprint)

| Deliverable | MCP method |
|-------------|------------|
| Workflow doc resource | `resources/read` → `vibevault://workflow` |
| Project context resource | `vibevault://project-setup` |
| Setup prompt | `prompts/get` → `setup-project-secrets` |
| Audit prompt | `prompts/get` → `who-read-secret` |

Agents discover workflows without the user typing instructions.

## Layer 4 — Provider Plugins (foundation)

| Deliverable | Path |
|-------------|------|
| Manifest schema | `ProviderPluginManifest.swift` |
| Loader | `PluginManifestLoader.swift` |
| Example manifest | `plugins/github-actions/manifest.json` |
| User plugin dir | `~/Library/Application Support/vibe-vault/plugins/` |

v0.3: SwiftPM plugin packages. v0.1: manifest + docs only; builtin providers unchanged.

## Layer 5 — VS Code Extension (scaffold)

| Deliverable | Path |
|-------------|------|
| Extension package | `extensions/vscode-vibevault/` |
| Commands | Open Vibe Vault, Install MCP, Show audit hint |
| MCP recommendation | Points to `vibevault mcp install --client vscode` |

Full secret picker UI deferred; MCP + skill cover v0.1.

## Verification

```bash
swift build && swift test && scripts/check-loc.sh
vibevault skill install --target all
vibevault mcp test
# In Cursor: confirm skill appears; MCP tools/list includes resources
```

## Out of scope (v0.2+)

- In-app skill editor / marketplace
- Devin cloud relay
- Generic plugin runtime (WASM)
- Telemetry
