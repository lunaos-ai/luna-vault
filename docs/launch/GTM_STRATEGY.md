# GTM Strategy - Vibe Vault 0.1

Source input: `/Users/shacharsolomon/Downloads/VibeVault_GTM_Strategy.docx`
Reviewed: July 19, 2026

## Executive Strategy

Vibe Vault should launch as the local credential boundary for AI coding agents,
not as a password manager. The wedge is specific: developers are giving Cursor,
Claude Code, Devin, VS Code, and terminal agents access to repos and commands,
while secrets still move through `.env` files, chat paste, shell history, and
agent config files.

The GTM motion should be product-led and bootstrap-friendly:

1. Prove trust before scale.
2. Lead with a demo, not copy.
3. Use `vibevault scan` as the no-commitment acquisition hook.
4. Launch in technical communities before Product Hunt.
5. Convert team-shaped usage after credibility exists.

## Positioning

For developers who use AI coding agents, Vibe Vault is a local credential
firewall that keeps API keys out of prompts, commits, and agent config files
with Touch ID approval and a per-agent audit log.

Unlike cloud secrets managers and password managers, Vibe Vault is built for
the agent-on-your-laptop threat model: local-first, no cloud account for Solo,
and running where the agents run.

## Competitive Positioning

The category now includes serious incumbents and adjacent platforms:
1Password, Bitwarden, Doppler, Infisical, HashiCorp Vault, Keeper, and Aembit
are all moving around AI-agent access, MCP, workload identity, or non-human
credentials.

Do not claim broad category ownership. The sharper GTM wedge is:

```text
Local credential boundary for AI coding agents on macOS: scan a repo, move
secrets out of .env, wire MCP and agent rules, import newly generated provider
keys from the browser, and audit which agent accessed what.
```

Public comparison pages now support that positioning:

- `https://vibevault.lunaos.ai/alternatives`
- `https://vibevault.lunaos.ai/vs-env-files`
- `https://vibevault.lunaos.ai/vs-1password`
- `https://vibevault.lunaos.ai/vs-bitwarden-mcp`
- `https://vibevault.lunaos.ai/vs-doppler`
- `https://vibevault.lunaos.ai/vs-infisical`

Use these pages in technical launch replies when users ask why this is not just
1Password, Bitwarden, Doppler, Infisical, or `.env` with better habits. The
source-of-truth competitive notes live in
`docs/launch/COMPETITIVE_ANALYSIS.md`.

## Why Now

Use quantified evidence in launch copy and content:

- GitGuardian reported 28.65 million new hardcoded secrets added to public
  GitHub commits in 2025, up 34% year over year.
- GitGuardian reported AI-service secrets reached 1,275,105 detections in
  2025, up 81% year over year.
- Public reporting on GitGuardian's 2026 data says Claude Code-assisted commits
  leaked secrets at 3.2%, compared with a 1.5% public GitHub baseline.
- Lakera reported that 428 of roughly 46,500 scanned npm packages contained
  `.claude/settings.local.json`; 33 files across 30 packages contained
  credentials, roughly one in thirteen settings files.
- 1Password shipped agent credential products in 2026, validating the category
  while leaving room for a local-first developer-tool wedge.

References live in `docs/launch/MARKET_EVIDENCE.md`.

## ICP Sequence

### ICP 1 - AI-native solo developer

Who: indie hacker, freelancer, or solo founder using Cursor or Claude Code
daily.

Pain: pasted a key into chat, committed `.env`, or fears a leak-driven cloud
bill.

Plan: Free.

Role in GTM: volume, word-of-mouth, GitHub stars, community proof.

Where: HN, X/Twitter, r/cursor, r/ClaudeAI, r/LocalLLaMA, Cursor forums,
Indie Hackers, AI-coding YouTube comments.

### ICP 2 - Startup team lead

Who: CTO or lead at a 3-15 person startup rolling agents across real repos.

Pain: no visibility into which local agent touched which credential.

Plan: Team, $19/month.

Role in GTM: first revenue and case-study material.

Where: HN, LinkedIn, CTO Slack/Discord groups, TLDR, Pragmatic Engineer-adjacent
audiences.

### ICP 3 - Agency / studio

Who: 5-25 developer agency or creative studio handling many client repos.

Pain: a leaked client credential is a reputation event; needs project isolation
and audit evidence.

Plan: Studio, $69/month.

Role in GTM: higher ACV bootstrap revenue and path to Company tier.

Where: LinkedIn, agency communities, referrals from ICP 1 and 2.

## Launch Gates

Do not launch broadly until these are true:

- Signed and notarized DMG; Gatekeeper accepts DMG and app.
- Homebrew install path works or launch copy explicitly uses the source-build
  fallback.
- Browser extension status is known and the copy reflects it.
- Hero demo exists: agent requests key, local approval, audit log entry.
- Scanner landing page exists and `vibevault scan` can be understood as a
  standalone starting point.
- Trust package exists: threat model, architecture summary, source-visible
  components, and a clear list of limits.
- 10-20 beta users have tried install -> first secret -> first agent read.

## Channel Order

1. Private beta / trusted technical smoke.
2. Niche AI coding communities.
3. X/Twitter technical thread with demo.
4. Show HN.
5. Direct creator/newsletter outreach.
6. Product Hunt after install and objections are clean.

Product Hunt should not be the first broad public launch. It should amplify a
working funnel after technical users have validated the install path and
positioning.

## 90-Day Plan

### Days 0-30 - Foundation and seeding

Focus: trust and activation.

Actions:

- Finish notarized distribution.
- Publish Homebrew or source fallback.
- Publish scanner landing page.
- Record the 45-60 second hero demo.
- Recruit 10-20 beta users.
- Participate in Cursor, Claude, and local AI coding communities without spam.
- Write the first evidence-backed post on AI-agent credential leaks.

Exit criteria:

- Install to first protected repo in under five minutes.
- First beta feedback has no install blockers.
- Launch materials are ready.

### Days 31-45 - Coordinated launch

Focus: visibility spike.

Actions:

- Soft launch in 2-3 niche communities.
- Post Show HN after no install blocker appears.
- Use HN feedback to update FAQ and README.
- Submit directories and extension updates.
- Launch Product Hunt only if install and browser import are clean.

Targets:

- 1,000+ installs.
- 300+ activated users.
- Objection list compiled.

### Days 46-90 - Engine and monetization

Focus: repeatability and first team revenue.

Actions:

- Publish incident-response explainers for agent credential leak stories.
- Build SEO pages around Cursor `.env` security, Claude Code secrets, MCP
  secrets, and alternatives.
- Convert team-shaped free usage manually.
- Add annual pricing copy once checkout is ready.
- Keep product cadence focused on activation blockers and trust gaps.

Targets:

- 1,500-3,000 installs.
- 40% activation.
- 10-20 paying teams.
- $300-800 MRR.
- One repeatable channel identified.

## Metrics

North-star metric: weekly active vaults where an agent was granted at least one
credential in the last seven days.

Funnel:

- Site visits.
- Downloads.
- Brew installs.
- First app open.
- First secret stored.
- First generated secret.
- First `vibevault scan`.
- First `vibevault cursor prepare`.
- First MCP read.
- First browser import.
- First encrypted sync push/pull.
- Team checkout click.
- Paid team conversion.

Telemetry must be opt-in and clearly disclosed. Heavy tracking would undercut
the trust story.

## Pricing Notes

Keep Solo free and complete. The free single-developer vault is the acquisition
engine.

Market flat team pricing explicitly:

- Team: $19/month for 5 developers.
- Studio: $69/month for 20 developers.
- Company: $249/month for 100 developers.

Add annual pricing later: two months free, primarily for bootstrap cash flow.

Do not add an Individual Pro tier yet; it would weaken the wedge before free
volume and trust exist.

## Immediate 14-Day Actions

1. If Apple Developer enrollment is blocked, switch to CLI-first launch mode and stop promoting the DMG.
2. Resolve notarization and Gatekeeper acceptance when Developer ID becomes available.
3. Publish or verify the Homebrew tap.
4. Record the hero demo.
5. Publish the scanner page and link it from the landing page.
6. Run 10-20 beta installs.
7. Document one Gemini browser import proof.
8. Keep the public security architecture page and threat model current.
9. Decide the open-source posture and make the answer explicit before HN.
10. Add annual pricing copy only after checkout supports it.
