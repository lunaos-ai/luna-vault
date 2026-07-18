# Implementation plan

Canonical product docs: `PRODUCT.md`, `DESIGN.md`, `CLAUDE.md` at repo root.

## Completed

- [x] Encrypted file vault + Keychain-wrapped master key
- [x] MigratingVaultStore (lazy Keychain → file)
- [x] Delete Keychain orphans after successful migrate
- [x] Vault dir/file excluded from iCloud backup
- [x] License VV1 re-verify on load
- [x] Provider Setup sheets (Cloudflare / Vercel / PushCI)
- [x] Import rename + project prefix; AI allow default off
- [x] MCP MigratingVaultStore + binary resolver; revoke-only `set_mcp_allowed`
- [x] Read-cache invalidation on mutate
- [x] Prefs Keychain standard ACL (no open ACL)
- [x] PRODUCT / landing / CHANGELOG / UI copy aligned to vault model
- [x] Luna deploy / monitor / test-validation report stubs

## Next (credentials / release)

- [ ] Notarized Developer ID release build + `v0.1.0` tag
- [ ] Homebrew tap push + launch posts
- [ ] Authenticate Cloudflare Observability for day-7 post-launch
