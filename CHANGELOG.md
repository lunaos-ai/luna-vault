# Changelog

All notable changes to Vibe Vault are documented here. Format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/); this product uses
[Semantic Versioning](https://semver.org/).

## [0.1.0] - 2026-06-09

First public build. Native macOS secret manager for AI-coding workflows:
local-first via the macOS Keychain, with an audited path for AI agents.

### Added
- **Cloudflare sync via Wrangler.** New "Cloudflare (Wrangler)" provider that
  authenticates through the user's existing `wrangler login` OAuth session (no raw
  API token). Secret values are piped over stdin to `wrangler secret bulk`, never
  passed as argv or logged.
- **Access Log.** Renamed the Audit tab to "Access Log" with an Outcome column
  (Allowed / Denied) and an Allowed / Denied / All filter.
- **Grant and denial auditing.** Every secret read now records whether access was
  granted or denied, with the requesting agent, session, project, and timestamp.
  Denied reads are auditable instead of silent.
- **Agent attribution.** The Touch ID prompt now names the requesting agent
  ("allow claude-code to read API_KEY"). MCP reads are attributed to the actual
  connected client (e.g. `mcp:cursor`) instead of a placeholder.
- **Key search autocomplete.** The vault search field suggests matching key names
  (prefix-first), and the provider push list has its own key search.
- **Liquid Glass design system.** Translucent floating surfaces, an ambient
  backdrop, depth shadows, and spring motion across every scene. All motion
  respects Reduce Motion; reproduced on macOS 14+ without the macOS 26-only
  `glassEffect()` API.
- **App-layer test suite.** A new `VibeVaultAppTests` target adds (a) view/scene
  smoke tests that render every screen with a fully stubbed environment, and
  (b) unit tests for `AppEnvironment`, the import flows, the MCP client installer,
  the expiry scheduler, and settings migration. Lifts overall line coverage from
  ~33% to ~73%; 58 new tests, 188 total. The MCP installer gained a URL-injectable
  core so its read/write path is tested without touching real client configs.
- **Stable dev code-signing.** `scripts/dev-codesign-setup.sh` creates a stable
  self-signed identity and sets the key partition list so Keychain "Always Allow"
  persists across rebuilds; `bundle-app.sh` pins bundle identifiers.

### Fixed
- **Keychain re-prompt loop.** Ad-hoc signing changed the app signature every
  build, so "Always Allow" never stuck. Builds now sign with a stable identity
  and pinned identifiers.
- **Subprocess deadlock.** `ProcessRunner` now drains stdout, stderr, and feeds
  stdin concurrently; a child filling the ~64KB stderr buffer can no longer hang.
- **Shell-env import hang.** `LoginShellEnv` discards stderr and drains stdout
  concurrently, so a chatty shell profile no longer stalls the import.
- **Revealed value leak.** A revealed secret value is now hidden when switching
  to another secret, leaving the pane, or if the selection changes while Touch ID
  is pending.
- **Dead buttons.** Install / Reinstall / Remove in AI Agents and the provider
  controls now have explicit button styles, fixing hit-testing inside forms.
- **Notification center crash in non-app hosts.** `AppNotifications` now resolves
  `UNUserNotificationCenter.current()` lazily, so constructing the expiry
  scheduler no longer aborts in a process without an app bundle proxy.
- **Unprofessional scanner status.** The project scanner result message is concise
  and rendered as a tinted status banner instead of a wall of comma-separated keys.

### Security
- Secret values are never written to logs or passed as process arguments.
- `pull` errors from the Wrangler provider report a transport error rather than a
  misleading HTTP status.
- Touch ID required on every read outside a configurable session-unlock window.
- No telemetry, no analytics, no network calls outside explicit provider syncs.

### Known limitations

- macOS 14 Sonoma or later. No iOS, Linux, or Windows in v0.1.
- Distribution builds are dev-signed. Developer ID signing + Apple notarization
  are required before public download; run `scripts/dev-codesign-setup.sh` for the
  local stable-signing workflow in the meantime.
