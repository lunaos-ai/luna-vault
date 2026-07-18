# Feature report: PushCI integration

**Date:** 2026-07-15  
**Status:** Green  
**Related project:** `/Users/shacharsolomon/dev/mobile/pushci`

## Summary

Integrated Vibe Vault with PushCI using the **local CLI bridge** — the only working secret sync path today. Cloud REST routes in `pushci/docs/API_SPEC.md` are not implemented yet.

## What shipped

### VaultCore
- `PushciCLI.swift` — wraps `pushci secret list|get|set`
- `PushciProvider.swift` — scope `project_path`, push/pull via CLI
- `PushciProviderTests.swift` — mocked runner tests

### App
- **Providers → PushCI** tab (`PushciSyncView`, `PushciConnectionCard`)
- Settings section (CLI sync docs)
- **Projects** scan → `PushciSyncBar` shortcut
- `AppEnvironment+Pushci` reconcile/push helpers

### MCP / CLI
- `reconcile_provider` / `push_secrets` accept `provider: pushci` + `project_path`
- Existing `vibevault push --to pushci` now functional

## Usage

```bash
# CLI
vibevault push --to pushci \
  --scope project_path=/Users/you/dev/mobile/pushci \
  --name GITHUB_TOKEN

vibevault pull --from pushci \
  --scope project_path=/Users/you/dev/mobile/pushci \
  --import-secrets
```

App: scan project → **Open PushCI sync** → Check sync → Push selected.

## Limits

- Secrets are **machine-bound** (PushCI AES-256-GCM + hostname salt)
- Requires `pushci` on PATH and project root with `.pushci/`
- No cloud dashboard sync until PushCI ships secret REST API

## Next (PushCI repo)

1. D1 `secrets` table + REST from `docs/API_SPEC.md`
2. Wire `secrets:read|write` scopes on routes
3. Vibe Vault Phase 2 REST adapter + Keychain token

## Test plan

- [ ] `pushci init` in a test repo; add vault secret; push from app
- [ ] `pushci secret list` shows synced keys
- [ ] MCP `push_secrets` with `project_path` + MCP-allowed secret
- [ ] Reconcile shows extra/missing between vault and PushCI store
