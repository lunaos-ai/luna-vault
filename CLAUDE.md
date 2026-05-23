# vibe-vault — Product CLAUDE Rules

Extends `/Users/shaharsolomon/dev/projects/CLAUDE.md`. Cannot weaken any portfolio rule.

## Product mission

Native macOS secret manager for AI-coding workflows. Replaces `.env` files and copy-paste from password managers. Local-first via macOS Keychain. AI-agent audit log. One-command sync to cloud providers (Cloudflare, Vercel, pushci.dev, GitHub Actions, AWS).

## Target user

Solo developer or small team using AI coding tools (Cursor, Claude Code, Windsurf) on macOS who currently:

- Stores secrets in `.env` files committed by accident.
- Copy-pastes from 1Password into terminal sessions.
- Has no audit trail of which AI agent read which secret.

## Architecture constraints

- **Platform**: macOS 14 Sonoma minimum. No iOS, no Linux, no Windows in v0.1.
- **Stack**: Native SwiftUI (App), Swift CLI (`vibevault`), shared `VaultCore` SwiftPM framework.
- **No third-party dependencies** in VaultCore except `swift-argument-parser` (CLI only) and system frameworks (Security, LocalAuthentication, sqlite3, Foundation).
- **Keychain service**: `kSecAttrService = "dev.vibevault"`.
- **Audit DB**: `~/Library/Application Support/vibe-vault/audit.db` (SQLite via system sqlite3).
- **App Group**: `group.dev.vibevault` for App↔CLI Keychain sharing.
- **File size cap**: 200 LOC per Swift file (non-blank, non-comment). Enforced by `scripts/check-loc.sh` in CI.
- **No network calls** in solo tier. Team tier (later) opt-in only.

## Product-specific test matrix

| Layer | Coverage target | Tool |
|-------|----------------|------|
| `KeychainStore` (secret read path) | 100% line + branch | XCTest |
| `AuditDB` (write path) | 100% line | XCTest |
| `AgentDetector` | 100% line | XCTest |
| `ProjectScanner` + parsers | 90% line | XCTest |
| Provider adapters | 90% line, network mocked | XCTest |
| CLI commands | 85% line | XCTest + spawn integration |
| SwiftUI views | Smoke (does it render) | XCTest + ViewInspector |

Overall: **>=90% line, >=85% branch** per portfolio rules.

## Product-specific security controls

- Every Keychain read **must** call `AuditDB.record(event:)` before returning the secret.
- Biometric (Touch ID) prompt required on every read unless within a session-unlock window (configurable, default 5 min).
- Provider adapters must verify HTTPS, use Bearer-token or HMAC-signed requests, and never log secret values.
- CLI `run` subcommand spawns child processes with `posix_spawn` and clears parent env of injected secrets after exec.
- No telemetry. No analytics. No crash reporting in solo tier.
- License key (Team tier) verified offline against embedded public key — no phone-home.

## Release checklist

- [ ] All Swift files ≤200 LOC (`scripts/check-loc.sh`).
- [ ] Coverage gates pass (90% line / 85% branch overall, 100% on KeychainStore/AuditDB read paths).
- [ ] SAST clean (`swift package plugin --allow-network-connections all sast` or equivalent).
- [ ] Dep scan clean (no CVEs in `swift-argument-parser` version).
- [ ] Secret scan clean (gitleaks on full repo, no test fixtures with real keys).
- [ ] App + CLI signed with Developer ID, notarized with Apple, stapled.
- [ ] Smoke test from plan §"Verification" passes on both Apple Silicon and Intel.
- [ ] Apple HIG review: menu bar icon, sidebar nav, content-first detail pane, dark mode, dynamic type, VoiceOver labels.
- [ ] CHANGELOG.md updated.
- [ ] Homebrew formula updated (luna-os/homebrew-tap).
- [ ] DMG ≤20 MB.

## Skills to use

- `cloudflare-deploy` — only for marketing site; product itself doesn't deploy to CF.
- `figma-implement-design` — when product designer hands off menu bar / window mocks.
- `skill-creator` — if a repeated workflow emerges (e.g. provider adapter generator).
