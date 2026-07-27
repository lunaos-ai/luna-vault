# Vibe Vault Capabilities And Roadmap

Last updated: 2026-07-26

This document is the repository-level source of truth for what Vibe Vault can do today, what is partially implemented, and what remains future work. It is intentionally written as a product and engineering map, not launch copy.

## Product Summary

Vibe Vault is a local-first credential boundary for AI coding workflows on macOS. It stores secrets in an encrypted local vault, gates sensitive reads through local approval, audits agent access, scans repositories for required secret names, and wires AI coding tools to request secrets through controlled interfaces instead of `.env` files or chat paste.

The current product is strongest for solo developers and small teams using Cursor, Claude Code, ChatGPT Codex, Gemini CLI, Devin, VS Code, terminal agents, Cloudflare Workers, Vercel, and local project workflows.

## Current Capabilities

### Local Vault

- Encrypted local vault backed by `VaultCore`.
- Master key stored in macOS Keychain.
- Secret model supports name, value, notes, creation time, update time, expiry, rotation interval, last rotated timestamp, MCP access flag, and attached MFA/TOTP setup URL.
- Local vault migration path from legacy Keychain-only items to the encrypted file vault.
- Secret list hides values by default and exposes masked previews only.
- Secret detail view supports copy, rotate, mark rotated, delete, metadata display, AI-agent access toggle, version preview, and single-secret restore.
- Local app and CLI share the same vault store.
- The encrypted vault document retains up to 50 atomic revisions per secret, including changes, rotations, imports, MFA changes, AI-access changes, restores, and deletion tombstones.
- Existing encrypted vault files migrate transparently to the versioned document format on first access.
- Vault toolbar exposes Recently Deleted recovery from encrypted deletion revisions.

### macOS App

- Native SwiftUI app with menu bar and main window surfaces.
- Sidebar sections for Overview, Vault, Import, Projects, Providers, AI Agents, Audit, and Settings.
- Add-secret sheet with secure value entry and generated-value helper.
- Vault list with search, sorting/grouping-oriented UI work, badges, bulk selection, recent activity, and detail view.
- Import screen for clipboard, files, password manager CSV exports, 1Password CLI, screenshots/images, shell environment, and system Keychain discovery.
- Settings surface for a selectable 5-minute to 8-hour shared app/CLI unlock lease and Team license, plus a dedicated Cloud Sync screen.
- Toast and feedback states for common operations.
- Reduce Motion aware UI patterns in supported motion surfaces.

### CLI

The `vibevault` CLI currently exposes these command groups:

- `add`: add or upsert a secret, with optional notes, expiry, and rotation interval.
- `list`: list vault secret names and metadata, with JSON output.
- `revoke`: delete a local secret. This does not revoke provider-side copies.
- `rotate`: update a value or mark rotation without changing the value.
- `import`: import from dotenv, shell env, 1Password CLI, clipboard, system Keychain discovery, password CSV, and image/OCR.
- `scan`: scan project files for required secrets, missing secrets, extra vault secrets, and tracked secret-file leaks.
- `run`: run a command with selected vault secrets injected into the environment.
- `push`: push selected secrets to Cloudflare, Vercel, or PushCI.
- `pull`: pull remote provider secret names and import values where the provider supports values.
- `mcp`: install and test the MCP server for AI clients.
- `browser`: install and inspect browser native messaging host manifests.
- `sync`: encrypted cloud/file sync and backup commands.
- `skill`: install the Vibe Vault agent skill.
- `guard`: install or check pre-commit hooks that block real secret files.
- `cursor`: prepare Cursor rules, MCP, skill, and guard.
- `agents`: install policy files for Codex, Claude, Gemini, and Cursor.
- `license`: activate, deactivate, inspect, and operator-issue offline licenses.

### Secret Generation

The app can generate secret values locally using secure random bytes:

- Hex.
- Base64 URL.
- Base64.
- Human app password style.
- UUID.
- Custom prefixed token.

Generator templates include common developer needs such as provider API keys, webhook tokens, database passwords, CSRF tokens, and app passwords. Generated drafts can be revealed, copied, cleared, or regenerated before saving.

### Imports

Implemented import paths:

- Dotenv files, including comments, quoted values, and `export` prefixes.
- Clipboard content containing `KEY=VALUE` lines.
- Shell environment variables filtered by glob patterns.
- 1Password CLI item JSON via `op item get`.
- Password manager CSV exports:
  - Auto-detect.
  - Apple Passwords.
  - Bitwarden.
  - 1Password CSV.
  - LastPass.
  - Dashlane.
- Screenshot/image OCR for visible credential labels and values.
- System Keychain discovery of likely secret names.

The app uses review sheets before writing imported rows so users can rename, skip, and inspect candidates.

### MFA/TOTP

- Secrets can carry an attached `otpauth://` TOTP setup URL.
- Password CSV import preserves MFA setup keys where available.
- Secret detail view can unlock and display/copy the current MFA code.
- Cloud Sync preserves TOTP setup URLs inside the encrypted sync snapshot.
- CLI/app metadata paths preserve whether a secret has TOTP.

### Project Scanning

The scanner detects required secret names from common local project files:

- `.env.example`.
- `.env`, `.env.local`, and dotenv variants.
- `wrangler.toml`, `wrangler.jsonc`, and `wrangler.json`.
- `vercel.json`.
- `package.json`.
- `next.config` style environment references.

It reports:

- Required secret names.
- Missing names compared with the local vault.
- Extra names in the vault that are not referenced by the project.
- Source files for detected names.
- Git-tracked secret-file leaks.

### Git Guard

- Pre-commit guard blocks committed `.env` and other sensitive local config files.
- Git leak scanner checks tracked secret-adjacent paths such as dotenv files, MCP configs, Cursor MCP config, and Claude local settings.
- Guard can be installed from CLI or as part of Cursor/project preparation.

### AI Agent Integration

Implemented agent integration surfaces:

- MCP server for AI clients.
- MCP installer for Cursor, VS Code, Devin, Claude Code, Claude Desktop, and all supported clients.
- Agent skill installer.
- Policy file installer for `AGENTS.md`, `CLAUDE.md`, `GEMINI.md`, and Cursor rules.
- Cursor-specific `prepare`, `rules`, and shadow MCP scanner commands.
- MCP resources for workflow, skill content, and live project setup scan.
- MCP prompts for setting up project secrets and auditing access.

MCP tools currently include:

- `list_secrets`: list names marked as MCP-accessible. Values are never returned by this tool.
- `read_secret`: read a value only when the secret has AI access enabled in the app.
- `set_mcp_allowed`: agents can revoke access, but cannot enable access.
- `scan_project`: scan a project for required secrets and git-tracked leaks.
- `get_audit_log`: read recent audit entries for MCP-allowed secrets.
- `suggest_secrets_for_task`: suggest secret names for a task without exposing values.
- `reconcile_provider`: compare local names with Cloudflare, Vercel, or PushCI.
- `push_secrets`: push MCP-allowed secrets to supported providers.

### Audit

- Every read through `VaultService` records an audit event.
- Audit includes secret name, action, agent/process identity, confidence, project context where available, and timestamp.
- Audit log can be queried in the app and through MCP.
- Reads for sync export, provider push, CLI run, MCP access, copy operations, and MFA display go through the audited service path.

### Provider Sync

Supported providers:

- Cloudflare Workers secrets.
- Vercel project environment variables.
- PushCI local CLI bridge.

Current provider capabilities:

- Push selected local secrets to provider targets.
- Pull provider secret names where values cannot be retrieved.
- Import pulled values where a provider supports values.
- Reconcile local and remote names.
- App setup screens for provider token/scope.
- Project-level sync bars for Cloudflare and PushCI.
- Cloudflare scope auto-detection from Wrangler config plus environment fallback.
- Wrangler config support for TOML, JSONC, and JSON.
- Cloudflare token fallback from `CLOUDFLARE_API_TOKEN`, `CF_API_TOKEN`, `CF_WRITE_TOKEN`, and `CF_TOKEN`.
- Vercel token storage and project/team scope support.

Provider sync is explicit. It does not make Vibe Vault a hosted cloud vault.

### Cloud Sync And Backup

Implemented today:

- `vibevault sync status`: shows local vault count and encrypted iCloud bundle status.
- `vibevault sync push --to icloud`: exports the local vault snapshot to iCloud Drive as an encrypted bundle.
- `vibevault sync pull --from icloud`: decrypts and imports the iCloud bundle on another Mac.
- `vibevault sync export --path <file>`: writes an encrypted backup bundle to any file path.
- `vibevault sync import --path <file>`: imports an encrypted backup bundle from a file path.
- `vibevault sync preview`: decrypts and compares a bundle without importing it.
- `vibevault sync backup`: creates timestamped encrypted history and applies a retention count.
- `vibevault sync history`: lists managed encrypted backups.
- `vibevault sync recovery-key --install`: generates a printable 256-bit recovery key and stores it in this Mac's Keychain for future backups.
- A dedicated Cloud Sync sidebar screen exposes Apple Account/iCloud Drive status, System Settings sign-in, the encrypted sync route, passphrase entry, recovery-key creation/export/import, sync/import actions, manual backup export/import, restore comparison, managed history, retention controls, and scheduled backups.
- The app verifies that the real iCloud Drive root exists and is writable before claiming an iCloud sync or managed backup succeeded.
- Restore comparison classifies new names, backup-newer names, local-newer names, and matching timestamps.
- Import policies can keep local values, use newer bundle values, or replace all matching values.
- Scheduled backups run when the app is open and the vault has been unlocked for the session.
- The menu-bar surface shows the latest managed backup time and whether scheduling is enabled.
- Cloud snapshots carry bounded encrypted per-secret revision history and merge revision IDs during import.
- Dedicated cloud sync and backup guide: `docs/CLOUD_SYNC_AND_BACKUP.md`.

Security model:

- Sync bundle file name: `vault.vvsync`.
- Default path: `~/Library/Mobile Documents/com~apple~CloudDocs/Documents/VibeVault/Sync/vault.vvsync`.
- Bundle format v2 encrypts each snapshot with a new random AES-256-GCM data key.
- The data key is wrapped independently by the passphrase and an optional 256-bit recovery key.
- Key derivation uses PBKDF2-SHA256 followed by HKDF-SHA256.
- Current KDF iteration count is 600,000, with downgrade checks on decrypt.
- Sync passphrase must be at least 12 characters.
- Manual sync passphrases are not stored by the app.
- Enabling scheduled backups explicitly stores that backup passphrase in this Mac's Keychain with `WhenUnlockedThisDeviceOnly` access.
- A configured recovery key is stored in this Mac's Keychain with `WhenUnlockedThisDeviceOnly` access and is included automatically in future app and CLI backup protection.
- Existing v1 passphrase-only bundles remain readable.
- File writes are atomic and set permissions to `0600`.
- Snapshot includes values and metadata, but only inside the encrypted envelope.

Important status:

- This is cloud sync through an encrypted user-controlled bundle, not a hosted LunaOS account sync service.
- There is no Vibe Vault cloud account, web vault, server-side key escrow, or hosted secret database for Solo.
- Scheduled backups do not run after the app exits.
- Per-secret local and imported revision history exists, but there is no side-by-side merge UI for divergent edits yet.
- Recovery requires the encrypted bundle and either its passphrase or a recovery key that protected that bundle.

### Browser Extension

Implemented:

- Chrome-compatible browser importer extension.
- Native messaging host installer through `vibevault browser install`.
- Browser support targets: Chrome, Brave, Edge, Chromium, or all.
- Chrome Web Store listing and package assets exist in `extensions/browser-vibevault/store/`.
- Extension sends keys only after user action.
- Extension does not use browser local storage for raw key values.
- Native host writes through `VaultService.live()`, preserving encrypted local storage and audit path.

Supported current provider pages are limited to host permissions declared in the extension manifest. Current manifest and content code include Google AI Studio/Gemini style key pages and Cloudflare dashboard coverage.

### VS Code Extension

- Thin companion extension exists under `extensions/vscode-vibevault`.
- It does not become a separate secret store.
- It guides MCP setup and agent integration back through `vibevault-mcp`.

### Team License

- Offline Team license support through signed `VV1` license keys.
- License activation, status, deactivation, and operator issue commands.
- Lemon Squeezy checkout/config docs and webhook notes exist.
- License verification happens locally against an embedded public key.
- Team license unlocks paid-seat behavior without requiring a hosted vault for Solo.

### Release And Distribution

Implemented assets and scripts:

- Swift package builds CLI, MCP server, browser host, and app.
- App bundle script.
- DMG creation script.
- Homebrew formula under `dist/homebrew`.
- Website publish scripts.
- iCloud publish/fetch helper scripts.
- Chrome Web Store packaging and upload scripts.
- GTM and readiness docs.
- Public website and landing assets under `marketing/landing`.

Current launch posture from existing readiness docs:

- Homebrew-first CLI path is ready.
- Public website, security page, AI-agent page, install page, and LLM guidance are documented as live.
- Latest native DMG is available from the install page as a clearly labeled, unnotarized preview.
- Chrome Web Store listing is documented as public.
- Native DMG/app notarization remains blocked until Apple Developer Program / Developer ID credentials are available.

## In Progress Or Partially Implemented

### Cloud Sync And Backup

Current state supports manual Mac-to-Mac sync, timestamped encrypted backup history, bounded per-secret versions, recovery keys, restore comparison, and in-app scheduling. It is not yet a seamless cross-device account sync.

Work still needed:

- System scheduling while the app is not running.
- Side-by-side merge UI when both Macs changed the same secret.
- Optional monitored backup folder in addition to manual file export.

### Browser Import

Current state is usable for supported pages and native-host import.

Work still needed:

- Broader provider coverage.
- More robust page-specific key detection tests.
- Manual Gemini browser test should remain part of release checks.
- Better extension popup onboarding for native host install failures.
- Better visible state for local app availability and license/sync status.
- Non-Chrome browser store packaging and submission, if prioritized.

### Native Mac Distribution

Current state:

- App can be built and locally installed.
- DMG artifact can be created.
- The current DMG is published as an explicitly labeled preview download.
- Developer ID notarization is blocked by Apple Developer Program enrollment.

Work still needed:

- Developer ID signing.
- DMG notarization.
- Stapled notarization ticket.
- Gatekeeper verification for app and DMG.
- Remove the preview warning and promote the notarized DMG as Gatekeeper-safe.

### Provider Integrations

Current providers are Cloudflare, Vercel, and PushCI.

Work still needed:

- More complete provider-specific pull/import where APIs allow values.
- Better environment/scope discovery for additional frameworks.
- Provider-side revoke/rotate actions. Current local revoke does not revoke provider credentials.
- Safer dry-run previews in app provider screens.
- Provider sync history and per-provider audit summary.

### Agent Governance

Current model is per-secret MCP allow plus audit.

Work still needed:

- Repository-scoped allow/deny rules.
- Temporary access grants.
- Policy-driven approval prompts.
- Blocked-access audit rows.
- Per-agent identity hardening.
- Per-project permission templates.
- Reason-required access policies.
- Better audit export.

### Team And Enterprise

Current state is offline license plus local workflows.

Work still needed:

- Seat management UI.
- Team deployment templates.
- Admin policy files.
- Audit export and longer retention settings.
- Offboarding workflow.
- MDM deployment profile.
- SSO/SCIM.
- SIEM export.
- Central policy management.
- Organization audit view.

### App UX

Recent work improved import screen spacing and generated value controls.

Work still needed:

- More visual QA across small and large windows.
- Keyboard navigation pass for every import/review action.
- VoiceOver labels pass for all custom controls.
- Better empty states for provider setup, cloud sync, and import review.
- More screenshot-based regression checks for dense screens.

### Documentation

Current docs are strong for launch, security, and CLI onboarding.

Work still needed:

- Provider-specific setup guides.
- Browser extension troubleshooting guide.
- Team license admin guide.
- Public compatibility matrix.
- Public data lifecycle page for sync, audit, local vault, and provider push.

## Future Roadmap

### Near-Term

- Publish this capability matrix as part of repo docs and keep it updated for every release.
- Keep the dedicated cloud sync/backup guide current as sync behavior changes.
- Improve browser extension onboarding and supported-provider docs.
- Keep recovery guidance current as backup behavior changes.
- Expand provider detection beyond current Wrangler/Vercel coverage.
- Keep Homebrew install and CLI-first onboarding frictionless while notarization is blocked.

### Mid-Term

- Background encrypted backups after the app exits.
- Per-secret multi-device conflict resolution.
- Repository-scoped policies.
- Time-limited agent access.
- Blocked-read auditing.
- Audit export.
- Provider-side revoke/rotation helpers.
- More browser provider importers.
- Better team license management and seat UX.

### Long-Term

- Hosted team control plane for policy, seats, and audit metadata, without turning Solo into a hosted cloud vault.
- Organization audit view.
- SSO and SCIM.
- SIEM export.
- MDM and enterprise deployment.
- Central policy management.
- Agent identity graph across local tools, MCP clients, repositories, and provider scopes.

## Explicit Non-Goals Today

- Vibe Vault does not protect a secret after an approved process receives it.
- Vibe Vault does not prevent misuse by a compromised local process or agent after approval.
- Vibe Vault does not revoke provider credentials when a local secret is deleted.
- Vibe Vault does not provide a hosted cloud vault for Solo.
- Vibe Vault does not provide SSO, SCIM, SIEM export, or centralized enterprise policy yet.
- Vibe Vault audit logs are local evidence, not tamper-proof centralized compliance records.

## Key Source Files

- App surfaces: `apps/VibeVaultApp/Features`.
- Cloud sync app surface: `apps/VibeVaultApp/Features/Settings/CloudSyncSettingsSection.swift`.
- Cloud sync environment: `apps/VibeVaultApp/AppEnvironment+CloudSync.swift`.
- Cloud sync crypto: `packages/VaultCore/Sources/VaultCore/Sync/CloudSync.swift`.
- Cloud sync models: `packages/VaultCore/Sources/VaultCore/Sync/CloudSyncModels.swift`.
- Recovery-key format: `packages/VaultCore/Sources/VaultCore/Sync/CloudRecoveryKey.swift`.
- Version-history model: `packages/VaultCore/Sources/VaultCore/Models/SecretRevision.swift`.
- Version-history app surface: `apps/VibeVaultApp/Features/Vault/SecretVersionHistoryView.swift`.
- CLI commands: `cli/vibevault/Commands`.
- MCP server: `cli/vibevault-mcp`.
- Scanner: `packages/VaultCore/Sources/VaultCore/Scanner`.
- Providers: `packages/VaultCore/Sources/VaultCore/Providers`.
- Importers: `packages/VaultCore/Sources/VaultCore/Importers`.
- Browser importer: `extensions/browser-vibevault`.
- VS Code companion: `extensions/vscode-vibevault`.
- Threat model: `docs/security/THREAT_MODEL.md`.
- Launch readiness: `docs/launch/READINESS.md`.
