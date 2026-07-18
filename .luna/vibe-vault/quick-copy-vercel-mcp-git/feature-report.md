# Feature report: Quick-copy · Vercel · MCP push · Git leaks

**Date:** 2026-07-15  
**Status:** Green — unit tests + LOC + CLI smoke pass  
**Plan:** `.luna/vibe-vault/quick-copy-vercel-mcp-git/plan.md`

## Summary

Shipped four expansion items as one autopilot pass:

| # | Feature | Result |
|---|---------|--------|
| 1 | Menu bar search + Touch-ID copy; ⌘N / ⌘F / ⌘C | Done |
| 2 | Vercel sync UI (Providers hub + Settings token) | Done |
| 3 | MCP `reconcile_provider` + `push_secrets` | Done |
| 4 | Git leak scan + `vibevault guard install` | Done |

Playwright E2E skipped (native SwiftUI macOS app). Coverage via XCTest + CLI smoke.

## What shipped

### 1. Three seconds to the secret
- Menu bar: searchable list, click row → Keychain read + clipboard + toast
- `AppEnvironment.copySecret(name:)` shared by menu bar and detail
- Commands: ⌘N add, ⌘F jump to vault search, ⌘C copy selected

### 2. Vercel provider parity
- Keychain token via `ProviderCredentialStore.vercelTokenKey`
- Settings section + `VercelSyncView` (check sync / push selected)
- Sidebar **Providers** hub: Cloudflare | Vercel

### 3. MCP push / reconcile
- Tools gated: push only for `mcpAllowed` secrets; values never returned
- Uses Keychain prefs + `ProviderRegistry` inside `vibevault-mcp`
- Every push audited via `recordEvent`

### 4. Git leak guardrails
- `GitLeakScanner` + `ScanResult.gitLeaks` on every project scan
- CLI: `vibevault scan --git-only` (exit 4), `vibevault guard install|status`
- Projects UI: `GitLeakBanner` + install hook button

## Verification

```
swift test                     → 91 tests, 0 failures
scripts/check-loc.sh           → 130 files, 0 over 200 LOC
vibevault scan --git-only      → clean on this repo
vibevault guard status          → not installed (expected)
```

## PR-ready test plan

- [ ] Menu bar: type partial secret name → click → Touch ID → paste elsewhere
- [ ] Main window: ⌘F focuses vault; ⌘C copies selected after Touch ID
- [ ] Settings: save Vercel token; Providers → Vercel → Check sync / Push
- [ ] MCP client: `tools/list` shows `push_secrets`, `reconcile_provider`
- [ ] MCP: `push_secrets` rejects non-MCP-allowed names
- [ ] Scan a repo with tracked `.env` → banner + `scan --git-only` exit 4
- [ ] `vibevault guard install` → commit of `.env` blocked by hook

## Security notes

- Provider tokens stay in Keychain prefs (never logged)
- MCP push does not bypass `mcpAllowed`
- Git scanner / hooks never print secret values
