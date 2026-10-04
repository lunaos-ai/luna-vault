# Changelog

All notable changes to Vibe Vault are documented here.

## Unreleased

### Fixed

- Windows loopback MCP uses an explicit Winsock version word and `IPPROTO_TCP.rawValue`. On Windows, ArgumentParser resolves to 1.8+ so SwiftCrossUI's WinUI path can build. CLI and MCP are built as separate SwiftPM products. Recovery prompts use the Windows C runtime instead of Glibc. The AppKit browser host is macOS-only, so Windows tests can build. Legacy v1 sync fixtures that call CommonCrypto stay on Apple platforms. Secret scanning allowlists RFC 6238 TOTP fixtures.

## [0.2.2] — 2026-10-04

### Fixed

- Windows CI and release builds use Windows SDK 10.0.26100 so Swift 6.2 can import WinSDK and ucrt.

## [0.2.1] — 2026-10-04

### Added

- Remembered project folders: Projects list in the macOS app, `vibevault projects`, and a desktop Projects tab. Scans persist missing/leak counts, restore the last project, and flag moved folders so they can be relocated.
- Release workflow builds Windows CLI zip/MSI and desktop zip and attaches them to the GitHub release.

### Changed

- Project scan treats a missing folder as an error instead of an empty result. Prefixed vault names (`PROJECT_KEY`) match required `KEY` using the project's saved prefix. `vibevault scan` and MCP `scan_project` remember the folder.

## [0.2.0] — 2026-09-20

### Added

- `vibevault duplicate NAME` to copy a secret (AI access starts off on the copy).
- Eye toggle on New Secret and Rotate sheets to show or hide the value while typing.
- JSON secret values: store a pretty-printed object or array, reveal it as formatted JSON, import `.json` maps or documents, and add via `vibevault add --format json --file`.
- macOS UI for JSON secrets: multiline editor (add, edit, rotate), formatted detail reveal, Text/JSON format switch, and import-review format labels.
- New Secret prefills name and value when the clipboard holds a single `KEY=value` line (or one JSON document). Pasting that line into the name field splits it the same way.
- Recovery-key fingerprints on new `.vvsync` bundles, a Keychain-backed recovery-key keyring, and Cloud Sync restore errors that distinguish a mismatched key from a corrupt backup.
- Passkey-gated loopback HTTP MCP for AI sandboxes (`vibevault mcp passkey`, `mcp serve --http`, `mcp sandbox start`). Binds 127.0.0.1 only; bearer token or `Authorization: Passkey`.
- Linux libsecret master-key storage (Secret Service via `dlopen`, mode-0600 file fallback and migration).
- Linux `.deb` and AppImage/AppDir packaging; Windows CLI MSI and desktop zip.
- Desktop Sandbox and Audit tabs (Linux / Windows).

### Changed

- CLI reads used by AI agents (`vibevault run`, and any `VaultService.read` from Cursor Agent, Claude Code, and similar) now honor Allow AI agents. Human terminals still inject every secret. Copies made with Duplicate start with AI access off.
- Cloud Sync recovery-key restore no longer reports a mismatched or rotated key as bundle corruption. Rotating the active key keeps previous keys for older backups.

### Fixed

- CI: Linux SOCK_STREAM Int32 conversion, Swift 6 concurrent HTTP response capture, Windows jobs on windows-2022 + SDK 10.0.22621.
- CI: Linux CLI smoke uses `--show-bin-path`; recovery-match tests pin ISO8601 dates; Windows Swift 6.2 with updated SDK modules.

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

[0.2.2]: https://github.com/lunaos-ai/luna-vault/releases/tag/v0.2.2
[0.2.1]: https://github.com/lunaos-ai/luna-vault/releases/tag/v0.2.1
[0.2.0]: https://github.com/lunaos-ai/luna-vault/releases/tag/v0.2.0
[0.1.4]: https://github.com/lunaos-ai/luna-vault/releases/tag/v0.1.4
[0.1.3]: https://github.com/lunaos-ai/luna-vault/releases/tag/v0.1.3
[0.1.2]: https://github.com/lunaos-ai/luna-vault/releases/tag/v0.1.2
[0.1.1]: https://github.com/lunaos-ai/luna-vault/releases/tag/v0.1.1
[0.1.0]: https://github.com/lunaos-ai/luna-vault/releases/tag/v0.1.0
