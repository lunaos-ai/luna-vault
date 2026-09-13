# Changelog

All notable changes to Vibe Vault are documented here.

## Unreleased

### Added

- Eye toggle on New Secret and Rotate sheets to show or hide the value while typing.
- Recovery-key fingerprints on new `.vvsync` bundles, a Keychain-backed recovery-key keyring, and Cloud Sync restore errors that distinguish a mismatched key from a corrupt backup.
- Passkey-gated loopback HTTP MCP for AI sandboxes (`vibevault mcp passkey`, `mcp serve --http`, `mcp sandbox start`). Binds 127.0.0.1 only; bearer token or `Authorization: Passkey`.
- Linux libsecret master-key storage (Secret Service via `dlopen`, mode-0600 file fallback and migration).
- Linux `.deb` and AppImage/AppDir packaging; Windows CLI MSI and desktop zip.
- Desktop Sandbox and Audit tabs (Linux / Windows).

### Changed

- Cloud Sync recovery-key restore no longer reports a mismatched or rotated key as bundle corruption. Rotating the active key keeps previous keys for older backups.

## [0.1.4] — 2026-08-25

### Fixed

- The one-click macOS installer now registers the Vibe Vault native messaging
  host for the published Chrome extension in Chrome, Brave, Edge, and Chromium,
  so detected provider keys can be saved immediately after installation.

## [0.1.3] — 2026-08-06

### Added

- Cross-session agent coordination (`vibevault agent`, bundled skill, nickname support).
- Mac App Store upload workflow and documentation.

### Engineering

- Split Swift source files to enforce 200 LOC limit.
- Version tag check in `scripts/gtm-check.sh` now uses the current git tag.

## [0.1.2] — 2026-07-28

### Fixed

- DMG installer now finds the app when macOS App Translocation hides the DMG siblings.

## [0.1.1] — 2026-07-28

### Fixed

- DMG installer now updates the bundled CLI, MCP server, browser host, shell PATH, and MCP client configuration together with the app.

## [0.1.0] — 2026-07-15

### Added

- Native macOS menu-bar app (encrypted local vault, Touch ID, audit log)
- CLI: `vibevault` add/list/scan/run/push/pull/mcp/skill/guard/cursor
- MCP server for Cursor, VS Code, Devin, Claude Code, Claude Desktop
- Agent skill + Cursor rules + Prepare for Cursor one-click
- Cloudflare, Vercel, PushCI (local CLI bridge) provider sync
- Git leak scan + pre-commit guard
- Import review (dotenv, clipboard, 1Password CLI)
- DMG installer + website / iCloud publish scripts
- Soft UI sounds and motion (Reduce Motion aware)
- UX smoke tour (`scripts/ux-smoke.sh`)
- Team license via Lemon Squeezy (offline Ed25519 `VV1` keys; `vibevault license`)

### Security

- Secrets: AES-GCM file vault; master key in Keychain (`WhenUnlockedThisDeviceOnly`)
- Every vault read via `VaultService` audited per agent
- MCP tools only return values for MCP-allowed secrets; agents may revoke access but cannot enable it
- Local-first; no telemetry in solo tier
- Team license verified offline against embedded public key (no phone-home)

## Unreleased

### Added

- PushCI cloud project secret onboarding: `vibevault push --to pushci --scope project_id=…`
  (JWT from `PUSHCI_TOKEN` or `~/.pushci/config.json`; optional `--allow-ci` for `ci_secret_names`)
- Recovery-key-wrapped local master-key envelope, Time Machine eligibility, and
  `vibevault recovery status|restore` for recovery after macOS Keychain loss.

### Changed

- Replaced Windsurf with Devin as a supported AI coding client (MCP, agent skill, audit filters)

### Fixed

- Existing encrypted vaults now fail closed when their Keychain master key is missing or malformed instead of silently generating an unusable replacement.
- Provider Setup sheets (Cloudflare / Vercel / PushCI token paste)
- Import review: rename rows + project prefix; AI allow default off
- MCP shares file vault store; `mcp test` finds bundled binary
- Read-cache invalidation on delete / rotate / update
- Legacy Keychain items deleted after successful migrate

[0.1.4]: https://github.com/lunaos-ai/luna-vault/releases/tag/v0.1.4
[0.1.3]: https://github.com/lunaos-ai/luna-vault/releases/tag/v0.1.3
[0.1.2]: https://github.com/lunaos-ai/luna-vault/releases/tag/v0.1.2
[0.1.1]: https://github.com/lunaos-ai/luna-vault/releases/tag/v0.1.1
[0.1.0]: https://github.com/lunaos-ai/luna-vault/releases/tag/v0.1.0
