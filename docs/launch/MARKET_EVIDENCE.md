# Market Evidence - AI Agent Credential Risk

Use this file as the source bank for public launch copy. Avoid unsupported
claims in posts or on the website.

## GitGuardian 2026 State of Secrets Sprawl

Source: https://blog.gitguardian.com/the-state-of-secrets-sprawl-2026/

Verified claims:

- GitGuardian reported 28.65 million new hardcoded secrets added to public
  GitHub commits in 2025.
- GitGuardian reported that represented a 34% year-over-year increase.
- GitGuardian reported AI-service secrets reached 1,275,105 detections in
  2025, up 81% year over year.
- GitGuardian reported eight of the ten fastest-growing detectors were tied to
  AI services.

Use in copy:

```text
GitGuardian's 2026 report found 28.65M new hardcoded secrets in public GitHub
commits in 2025 and an 81% year-over-year rise in AI-service secret leaks.
```

## Claude Code Assisted Commit Leak Rate

Source to verify before paid/public homepage use:

- GitGuardian 2026 report and derivative coverage mention Claude Code-assisted
  commits leaking secrets at 3.2% versus a 1.5% public GitHub baseline.

Use in community copy only after source check:

```text
Public reporting on GitGuardian's 2026 data says Claude Code-assisted commits
leaked secrets at more than double the public GitHub baseline.
```

## Lakera Claude Settings Scan

Source: https://www.lakera.ai/blog/your-ai-coding-assistant-just-shipped-your-api-keys

Verified claims:

- Lakera reported scanning approximately 46,500 npm packages.
- 428 contained `.claude/settings.local.json`.
- 33 files across 30 packages contained credentials.
- Lakera characterized that as roughly one in thirteen settings files containing
  something sensitive.

Use in copy:

```text
Lakera found `.claude/settings.local.json` files inside published npm packages;
roughly one in thirteen of those settings files contained sensitive data.
```

## 1Password Category Validation

Sources:

- https://1password.com/press/2026/mar/1password-unified-access
- https://1password.com/blog/1password-for-claude
- https://1password.com/press/2026/july/1password-for-claude

Verified claims:

- 1Password announced Unified Access for AI agent security in March 2026.
- 1Password announced 1Password for Claude in July 2026.
- 1Password describes a zero-exposure architecture for Claude credential access.
- This validates the category of credential access for AI agents.

Use in copy:

```text
1Password moving into agent credential access validates the category. Vibe
Vault's wedge is narrower and local-first: AI coding agents on your Mac.
```

## Copy Rules

Do:

- Cite GitGuardian and Lakera when using numbers.
- Tie evidence directly to the product: local agents, `.env`, MCP, and config
  files.
- Keep claims specific to Vibe Vault's actual features.

Do not:

- Say Vibe Vault prevents all leaks.
- Say scanner detects every possible secret value.
- Say Vibe Vault revokes provider credentials automatically.
- Say cloud sync is a hosted cloud vault.
- Use the Claude Code 3.2% number on the homepage until the exact primary
  report text is pinned.
