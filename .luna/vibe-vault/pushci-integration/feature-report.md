# PushCI integration — feature report

## Status

Phase 2 (cloud project secrets) implemented in luna-vault.

## What shipped

- `PushciConfig` — auth from env / prefs / `~/.pushci/config.json`
- `PushciCloudAPI` — GET/PUT project secrets + optional `ci_secret_names` merge
- `PushciProvider` dual mode: `project_id` (cloud) or `project_path` (local CLI)
- CLI: `vibevault push --to pushci --scope project_id=… [--allow-ci]`
- MCP: `push_secrets` / `reconcile_provider` accept `project_id`, `environment`, `allow_ci`
- App: Providers → PushCI cloud project ID + CI allowlist toggle

## Tests

`swift test --filter 'PushciProviderTests|PushciCloudAPITests'` — 10 passed.

## Usage

```bash
# Requires: pushci login (JWT in ~/.pushci/config.json) and vault secret present
vibevault push --to pushci \
  --scope project_id=656ADCE5-1F33-45DD-8DC6-23F77BFE4264 \
  --scope environment='*' \
  --name MY_SECRET \
  --allow-ci
```

Values are never printed. PUT already adds names to execution policy `secret_names`.
