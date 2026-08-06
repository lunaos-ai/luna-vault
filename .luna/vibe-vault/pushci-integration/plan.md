# PushCI integration plan

**Swarm topology:** star (VaultCore adapter → App UI → MCP/CLI)

## Context

PushCI stores secrets two ways:
1. **Local CLI** — `.pushci/secrets.enc` via `pushci secret set|get|list`
2. **Cloud API** — `PUT/GET /api/projects/:projectId/secrets` (JWT from `pushci login` / `~/.pushci/config.json`)

## Phase 1 — CLI bridge (shipped)

| Layer | Deliverable |
|-------|-------------|
| VaultCore | `PushciCLI` + `PushciProvider` local mode |
| App | Providers → PushCI tab, project path, reconcile/push |
| MCP | `project_path` scope on push/reconcile |
| CLI | `vibevault push --to pushci --scope project_path=…` |

## Phase 2 — cloud project secrets (this change)

| Layer | Deliverable |
|-------|-------------|
| VaultCore | `PushciConfig` + `PushciCloudAPI` + cloud mode on `project_id` |
| CLI | `vibevault push --to pushci --scope project_id=… [--allow-ci]` |
| MCP | `project_id`, `environment`, `allow_ci` on `push_secrets` |
| App | Cloud project ID field + optional CI allowlist toggle |

Auth order: `PUSHCI_TOKEN` / `PUSHCI_JWT` → Keychain prefs → `~/.pushci/config.json` `token`.

Optional `--allow-ci` merges pushed names into execution policy `ci_secret_names`.
PUT already adds names to `secret_names`.

## Verification

```bash
cd luna-vault && swift test --filter PushciProviderTests

# Cloud onboard (values never printed):
vibevault push --to pushci \
  --scope project_id=656ADCE5-1F33-45DD-8DC6-23F77BFE4264 \
  --scope environment='*' \
  --name MY_SECRET \
  --allow-ci

# Local CLI fallback:
vibevault push --to pushci --scope project_path=/path/to/repo --name MY_SECRET
```
