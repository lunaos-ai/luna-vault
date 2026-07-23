# GTM Runbook - Vibe Vault 0.1

This runbook is the execution order for launch. It separates what can be done
now from what must wait for account-owned actions.

## Launch Rule

Do not launch the Mac app broadly until the app gates pass. If Apple Developer
Program enrollment is blocked, switch to CLI-first launch mode and do not ask
first-time users to bypass Gatekeeper for a security tool.

## Level 0 Gates

Run:

```bash
vibevault scan
bash scripts/gtm-check.sh
swift test
swift build --product VibeVaultApp
xcrun stapler validate build/VibeVault.dmg
spctl -a -vv -t open build/VibeVault.dmg
spctl -a -vv build/VibeVault.app
```

Required before a CLI-first Show HN:

- [ ] `vibevault scan` has 0 required missing secrets.
- [ ] `swift test` passes.
- [ ] `swift build --product VibeVaultApp` passes.
- [ ] `https://vibevault.lunaos.ai/` is live.
- [ ] `https://vibevault.lunaos.ai/download` returns the CLI-first install page.
- [ ] Homebrew install is verified: `brew tap finsavvyai/tap && brew install vibevault`.
- [ ] One manual Gemini key import has been performed and documented.
- [ ] Browser extension public listing verifies if launch copy links to it.

Required before a native Mac app launch:

- [ ] DMG has a stapled notarization ticket.
- [ ] Gatekeeper accepts `build/VibeVault.dmg`.
- [ ] Gatekeeper accepts `build/VibeVault.app`.
- [ ] Notarized DMG download is published.

## Current Status - July 22, 2026

Ready:

- Website is live at `https://vibevault.lunaos.ai/`.
- Scanner page is expected at `https://vibevault.lunaos.ai/scan`.
- Security architecture page is expected at `https://vibevault.lunaos.ai/security`.
- AI-agent landing page is expected at `https://vibevault.lunaos.ai/agents`.
- LLM-readable guidance is expected at `https://vibevault.lunaos.ai/llms.txt`.
- Chrome Web Store listing is public at `https://chromewebstore.google.com/detail/vibe-vault-importer/nfeigikipagiccmhlolgfbeienkckbpc`.
- Worker health returns `{ "ok": true, "host": "vibevault.lunaos.ai" }`.
- Landing page includes local random key generation copy.
- `build/VibeVault.dmg` exists.
- `build/VibeVault-Browser-Importer.zip` exists.
- Homebrew tap is public at `https://github.com/finsavvyai/homebrew-tap`.
- `brew tap finsavvyai/tap && brew install vibevault` has been verified.
- Public source repo is live at `https://github.com/lunaos-ai/luna-vault`.
- GitHub release `v0.1.0` is live with CLI, MCP, browser-host, DMG, and extension assets.
- Store listing, privacy text, review notes, and screenshots exist under `extensions/browser-vibevault/store/`.
- `swift test` passed with 144 tests after the generator feature.
- `bash scripts/gtm-check.sh` reports 0 failures.
- Source-backed GTM strategy and market evidence live under `docs/launch/`.
- Public trust page covers architecture, lifecycle, controls, source-visible core, and non-goals.
- Apple Developer enrollment fallback is documented in `docs/launch/APPLE_DEVELOPER_BLOCKED.md`.
- Git leak scanning covers tracked `.env*`, `.mcp.json`, `.cursor/mcp.json`,
  and `.claude/settings.local.json` paths.

Blocked:

- DMG is not notarized or stapled.
- `spctl` rejects both current DMG and app.
- `NOTARYTOOL_*` credentials are not present in the current environment.
- Apple Developer Program enrollment is currently blocked, so Developer ID
  signing and notarization cannot be completed in this environment.
- HN, Reddit, X, Product Hunt, and community posts require the owner's accounts.

## Recommended Execution Order

### Phase 0 - Trust and evidence package

1. Keep the public threat model linked from launch materials.
2. Use `docs/launch/MARKET_EVIDENCE.md` as the source bank for public numbers.
3. Record the hero demo: agent requests key, local approval, audit log entry.
4. Make the scanner page the no-commitment acquisition path.
5. Decide the open-source posture before Show HN.

### Phase 1A - Homebrew-first CLI launch while Apple is blocked

Use this mode if Apple Developer Program enrollment cannot be completed.

1. Keep `/download` pointed at the CLI-first install page, not the raw DMG.
2. Lead public copy with Homebrew:

   ```bash
   brew tap finsavvyai/tap
   brew install vibevault
   vibevault scan
   ```

3. Promote `vibevault scan`, `vibevault guard install`, MCP setup, browser import, and source-visible core.
4. Do not promote the unnotarized DMG to first-time users.
5. Keep Product Hunt waiting; use technical communities and Show HN only with the Homebrew-first/no-notarized-DMG caveat.

### Phase 1B - Fix native app install trust

1. Export Apple notary credentials in the shell or make them available through Vibe Vault:

   ```bash
   export NOTARYTOOL_APPLE_ID="..."
   export NOTARYTOOL_TEAM_ID="..."
   export NOTARYTOOL_PASSWORD="..."
   ```

2. Rebuild and notarize:

   ```bash
   NOTARIZE=1 NOTARIZE_DMG=1 bash scripts/release.sh release
   ```

3. Verify:

   ```bash
   xcrun stapler validate build/VibeVault.dmg
   spctl -a -vv -t open build/VibeVault.dmg
   spctl -a -vv build/VibeVault.app
   ```

4. Publish the DMG/download surface:

   ```bash
   bash scripts/publish-to-website.sh
   ```

### Phase 2 - Publish developer install path

1. Publish/update the Homebrew formula in `finsavvyai/homebrew-tap`.
2. Verify on a clean machine or temp Homebrew prefix:

   ```bash
   brew untap finsavvyai/tap || true
   brew tap finsavvyai/tap
   brew install vibevault
   vibevault --version
   vibevault --help
   ```

3. If the tap regresses, launch copy must temporarily fall back to source build.

### Phase 3 - Browser import proof

1. Build host and extension package:

   ```bash
   swift build --product vibevault-browser-host
   bash scripts/package-browser-extension.sh
   ```

2. Install native host:

   ```bash
   vibevault browser install --browser chrome --extension-id <extension-id>
   ```

3. Manual proof:

   - Open Google AI Studio / Gemini.
   - Generate a test API key.
   - Use the provider copy button or visible key detection.
   - Save as `GEMINI_API_KEY` through the Vibe Vault panel.
   - Confirm `vibevault list` shows the key name.
   - Confirm `vibevault read GEMINI_API_KEY` or app read works through the normal gated path.

4. Record a short clip or screenshots for launch support.

### Phase 4 - Private smoke

Send to 10-20 trusted developers:

- macOS developers using Cursor/Claude Code.
- People who deploy to Cloudflare/Vercel.
- Security-minded indie devs.
- One person unfamiliar with the project.

Ask only for:

- Could you install it?
- Could you create/import one key?
- Could you run `vibevault cursor prepare`?
- What sentence made the product click?
- What felt risky or unclear?
- Would the scanner alone have made you try the product?

### Phase 5 - Technical launch

Launch channels in this order:

1. Cursor/Claude/AI dev communities.
2. LocalLLaMA.
3. X/Twitter technical thread.
4. Show HN.
5. Follow-up with the live Chrome importer for browser-created provider keys.

Show HN should happen only when at least one install path is friction-free.

### Phase 6 - Product Hunt

Do Product Hunt after:

- HN/community objections are understood.
- Install funnel is stable.
- Browser extension listing is live and install flow has been smoke-tested.
- Screenshots/video are polished.
- Support queue can be handled for a full day.

## Launch Day Operating Plan

T-24h:

- Run Level 0 gates.
- Open a clean macOS test account or second Mac and build/install from the public path.
- Check `/download`, `/privacy`, `/api/checkout`, and `/health`.
- Prepare a demo clip and screenshots.
- Put `docs/launch/LAUNCH_PACK.md` snippets in a notes file for quick posting.

T-2h:

- Re-run `bash scripts/gtm-check.sh`.
- Re-run Gatekeeper checks.
- Confirm website and `/download` install page.
- Confirm checkout links.
- Confirm Chrome Web Store listing still shows `Add to Chrome`.

Launch:

- Post one community first.
- Answer every substantive technical reply for 60-90 minutes.
- Post Show HN after the first community has not exposed an install blocker.
- Keep replies technical, short, and specific.

T+6h:

- Update FAQ or README for repeated objections.
- Patch copy if people misunderstand local-first/cloud sync.
- Triage bugs by install blocker, data safety blocker, UX confusion, nice-to-have.

T+24h:

- Publish a short changelog/follow-up.
- Move repeated questions into docs.
- Decide whether Product Hunt is ready or should wait.

## 90-Day Targets

- Launch week visits: 10,000+.
- Cumulative installs: 1,500-3,000.
- Activation: 40% of installs reach first credential plus first agent approval.
- Retention: 40% of activated vaults active weekly.
- Revenue: 10-20 paying teams, roughly $300-800 MRR.
- Trust: one repeatable channel and a documented objection list.

## Metrics

Track these manually or with privacy-safe server logs:

- Landing visits.
- `/download` clicks.
- Brew installs or GitHub release downloads.
- First app open.
- First secret created.
- First generated secret.
- First browser import.
- First `cursor prepare`.
- First MCP read.
- First provider sync.
- First encrypted sync push/pull.
- Team checkout clicks.
- Support issues by category.

## Support Triage

Severity 0:

- Data loss.
- Secret exposure.
- Incorrect audit behavior.
- Crash on launch.

Severity 1:

- DMG install blocked.
- Homebrew install blocked.
- Native host install blocked.
- Browser import cannot save after showing a key.
- Sync cannot decrypt a valid bundle.

Severity 2:

- Confusing copy.
- Missing provider pattern.
- Poor error message.
- UI friction.

## Message Discipline

Say:

- "local credential runtime for AI coding agents"
- "encrypted local vault"
- "master key in macOS Keychain"
- "optional encrypted sync bundle"
- "browser importer for supported provider dashboards"

Do not say:

- "cloud password manager"
- "enterprise secrets platform" for v0.1
- "prevents all leaks"
- "malware-proof"
- "fully automated provider rotation" unless provider revocation is actually implemented
