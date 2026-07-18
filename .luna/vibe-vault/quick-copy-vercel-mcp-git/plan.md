# Plan: Quick-copy, Vercel UI, MCP push, Git leaks

## Features

1. **Menu bar quick-copy + ⌘F** — searchable menu bar, Touch-ID gated copy, vault ⌘F/⌘C
2. **Vercel sync UI** — token, scope, reconcile/push (Cloudflare parity)
3. **MCP push/reconcile** — tools for Cloudflare (and Vercel) with MCP-allowed gate
4. **Git leak guardrails** — tracked `.env*` detection in scan + CLI hook install

## Tasks

| # | Task | Layer |
|---|------|-------|
| 1 | `GitLeakScanner` + `ScanResult.gitLeaks` | VaultCore |
| 2 | Vercel credential store + registry wiring | VaultCore |
| 3 | `ProviderNameReconcile` (generic) | VaultCore |
| 4 | Unit tests for 1–3 | Tests |
| 5 | Menu bar search/copy + `copySecret` + shortcuts | App |
| 6 | Vercel app UI + providers hub | App |
| 7 | MCP push/reconcile tools | MCP |
| 8 | CLI `scan` leaks + `guard install` | CLI |
| 9 | Build, LOC, review, feature-report | Meta |

## Constraints

- ≤200 LOC / Swift file
- Accent only on actions
- Secrets never logged
- MCP push only for `mcpAllowed` secrets
