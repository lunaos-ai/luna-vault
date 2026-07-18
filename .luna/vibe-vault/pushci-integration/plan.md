# PushCI integration plan

**Swarm topology:** star (VaultCore adapter → App UI → MCP/CLI)

## Context

PushCI (`/Users/shacharsolomon/dev/mobile/pushci`) stores secrets locally in `.pushci/secrets.enc` via `pushci secret set|get|list`. Cloud REST secret CRUD is documented but not shipped.

## Phase 1 (this sprint) — CLI bridge

| Layer | Deliverable |
|-------|-------------|
| VaultCore | `PushciCLI` + real `PushciProvider` |
| App | Providers → PushCI tab, project path, reconcile/push |
| MCP | `project_path` scope on push/reconcile |
| CLI | `vibevault push --to pushci --scope project_path=…` |

## Phase 2 (pushci repo) — cloud API

When pushci ships `/api/repos/:id/secrets`:

1. Add REST mode to `PushciProvider` (Bearer `PUSHCI_TOKEN` / `pctk_*`)
2. Keychain token in `ProviderCredentialStore`
3. Environment `secretRefs` binding via project env routes

## Verification

```bash
cd luna-vault && swift test --filter PushciProviderTests
vibevault push --to pushci --scope project_path=/path/to/pushci --name MY_SECRET
```
