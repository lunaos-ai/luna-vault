# Changelog

All notable changes to Vibe Vault are documented here.

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

### Changed

- Replaced Windsurf with Devin as a supported AI coding client (MCP, agent skill, audit filters)

### Fixed

- Provider Setup sheets (Cloudflare / Vercel / PushCI token paste)
- Import review: rename rows + project prefix; AI allow default off
- MCP shares file vault store; `mcp test` finds bundled binary
- Read-cache invalidation on delete / rotate / update
- Legacy Keychain items deleted after successful migrate

[0.1.0]: https://github.com/luna-os/luna-vault/releases/tag/v0.1.0
