# Post-Launch Review

**Scope**: vibe-vault (project-level)
**Launch Date**: Soft — GTM pack dated 2026-07-15; marketing Worker ship commit `62ca9bb` (2026-07-18)
**Review Period**: N/A (pre-7-day / incomplete production window)
**Reviewer**: Luna Post-Launch Review Agent
**Review Date**: 2026-07-18

---

## Review posture (read first)

This is a **pre-7-day / soft-launch** review, not a full post-launch retrospective.

| Prerequisite | Status |
|--------------|--------|
| `.luna/vibe-vault/deployment-report.md` | **Missing** |
| `.luna/vibe-vault/monitoring-observability-report.md` | **Missing** |
| `.luna/vibe-vault/test-validation-report.md` | **Missing** |
| `.luna/vibe-vault/requirements.md` | Present (thin pointer to PRODUCT / CLAUDE / AGENTS) |
| Code review | Present — **APPROVE WITH CHANGES** (2026-07-18) |
| 7 days of production metrics | **Unavailable** |

**Do not treat the numbers below as launch KPIs.** Where something was probed live on 2026-07-18, it is labeled as a **spot check**. User counts, conversion rates, error budgets, and uptime SLOs are **not invented**.

Two surfaces are reviewed separately:

1. **Marketing site (Cloudflare Worker)** — `https://vibevault.lunaos.ai` — the only cloud surface that can yield HTTP evidence.
2. **Native app / CLI / MCP** — local-first Solo product with **no telemetry, no analytics, no crash reporting** (`CLAUDE.md` / `PRODUCT.md`). Adoption and crash rates are unknown **by design**, not only by missing instrumentation.

Cloudflare Observability MCP is `needsAuth` — Worker analytics, request volume, and error rates from the CF dashboard were **not** collected for this review.

---

## 1. Objectives vs. status

### Product objectives (PRODUCT / CLAUDE)

| Objective | Soft-launch status |
|-----------|-------------------|
| Local encrypted vault; master key in Keychain; Touch ID gated reads | **In progress.** Working tree includes Keychain-wrapped master key (`KeychainMasterKey.swift`) and related vault migration; largely **uncommitted**. Public CHANGELOG still describes “Keychain secrets” while shipped baseline had file vault + plaintext `master.key` (code-review C1/C2). |
| Audit every secret read per agent | Met in design (`VaultService` façade); coverage gates not validated (no test-validation report). |
| MCP allowlist — human decides what AI sees | **Fixes present in working tree** (revoke-only `set_mcp_allowed`, import `allowForAI` default off) per implementation-plan; **not committed / not in a notarized release**. Code review still flags residual risks (provider open ACL, name enumeration). |
| Solo: full-featured, offline, no phone-home | Met by policy. |
| Team: Lemon Squeezy → offline VV1 license | Worker `/api/checkout` returns `configured: true` with Team/Studio/Company URLs (spot check). License crypto approved in code review; seat enforcement intentionally weak (Solo = full product). |
| Provider sync (CF / Vercel / PushCI) | Implemented in-repo; Setup sheets called out as GO in code review. |

### GTM objectives (`.luna/vibe-vault/gtm/`)

| Criterion | Status |
|-----------|--------|
| LICENSE, CHANGELOG 0.1.0, CLI version, formula, landing, launch pack | In-repo; `scripts/gtm-check.sh` → **0 fail, 2 warn** (notary creds; brew tap verify) |
| Landing live | **Yes** — Worker serves HTML 200 (spot check) |
| Notarized Developer ID DMG + `v0.1.0` tag + GitHub Release | **Not done** — no `v*` tags locally; gtm-check warns on notary; CHANGELOG links a release URL that is not confirmed shipped |
| Homebrew tap push, LAUNCH_PACK posts, Cursor Directory submit | Remaining human / credential steps |
| Public Gatekeeper-safe install path | **Blocked** until notarize |

**Verdict on objectives:** Marketing + checkout plumbing are soft-live. Public product launch (notarized binary + honest security posture on main) is **not** complete.

---

## 2. Performance (what is knowable)

### Marketing Worker (spot checks, 2026-07-18)

| Probe | Result |
|-------|--------|
| `GET https://vibevault.lunaos.ai/` | HTTP **200**, ~23.6 KB HTML, `cf-cache-status: HIT`, ~0.43 s |
| `GET /health` | HTTP **200**, `{"ok":true,"host":"vibevault.lunaos.ai"}`, ~0.09 s |
| `GET /api/checkout` | HTTP **200**, JSON with store/product IDs, three Lemon Squeezy checkout URLs, `configured: true`, ~0.13 s |
| `GET /download` | HTTP **302** → `https://lunaos.ai/download/vibevault` |

No multi-day latency percentiles, error rates, or cache hit ratios. No Worker deploy timestamp beyond git commit `62ca9bb` (same day as this review). `wrangler deploy` docs exist under `workers/vibevault/`; no deployment-report artifact.

### Native app

- No RUM / crash / perf telemetry by design.
- Code review notes `EncryptedVaultStore.loadAll()` decrypts the full vault per op — acceptable for Solo scale; not measured in production.
- Release checklist items (coverage 90/85, LOC gate, notarize) were **not** re-run as a formal test-validation report for this review. Spot: `gtm-check.sh` LOC OK; notary WARN.

---

## 3. Adoption & engagement

| Signal | Status | Why |
|--------|--------|-----|
| Active installs / DAU / WAU | **Unknown by design** | Solo tier: no analytics |
| MCP/agent secret-read volume | **Unknown by design** | Local `audit.db` only; no central rollup |
| Landing unique visitors / funnel | **Unknown (missing instrumentation / CF auth)** | Worker live; Observability MCP unauthenticated; no deployment/monitoring reports |
| Team checkout starts / paid seats | **Unknown** | Checkout URLs configured; no order webhook metrics available here |
| Homebrew installs | **Unknown** | Tap push not verified |
| Show HN / X / PH posts | **Not confirmed posted** | Launch pack exists in `docs/launch/` |

**Honest split:** App adoption cannot be inferred from the marketing site being up. Site traffic cannot be stated without CF analytics access.

---

## 4. Incidents & reliability

| Item | Finding |
|------|---------|
| Production incidents (7-day) | **None documented** — no monitoring report, no incident log in `.luna/` |
| App crash spikes | **Unknown by design** |
| Worker outages | Not observed in spot checks; no historical uptime % |
| Security incidents | None reported. Code review identified **pre-release** trust-model issues (C1/C2, M1/M2), with remediation largely in the **uncommitted** working tree |

---

## 5. What went well

1. **GTM scaffolding shipped in-repo** (2026-07-15 feature report): LICENSE, CHANGELOG, formula, landing, launch pack, release workflow, `gtm-check.sh`.
2. **Marketing Worker is live** with health, landing, checkout config, and download redirect — strangers can reach pricing/checkout without a native install.
3. **Lemon Squeezy path configured** (`configured: true` on `/api/checkout`) with offline VV1 model aligned to “no phone-home.”
4. **Code review was rigorous** and correctly blocked notarized public 0.1 on trust-model drift and AI-access boundary gaps.
5. **Remediation started the same day** as the review: Keychain-wrapped master key, MCP revoke-only, `allowForAI` default off, cache invalidation — reflected in `.luna/vibe-vault/implementation-plan.md` and current working tree.
6. **Product honesty on telemetry**: choosing no Solo analytics avoids fake “engagement dashboards” and matches the Locksmith Bench voice.

---

## 6. Challenges & gaps

1. **Formal Luna launch reports missing** — deployment, monitoring, test-validation — so this review cannot close the usual `/ll-postlaunch` evidence loop.
2. **Soft launch ≠ public launch** — no `v0.1.0` tag observed, notarization blocked, brew tap unverified, LAUNCH_PACK not confirmed published.
3. **Large uncommitted security-sensitive tree on `main`** — vault crypto, MCP policy, Keychain helpers still untracked/modified; hard to ship, bisect, or claim “fixed in 0.1.”
4. **Copy / CHANGELOG lag** — marketing and CHANGELOG still lean “Keychain secrets” while architecture is encrypted file vault + Keychain master key; must stay aligned before GTM claims.
5. **Residual majors from code review** may remain after C1/M1/M2 fixes: provider token open ACL (M3), coverage re-point (M5), MCP name enumeration (m1).
6. **No central way to know if dogfood works** beyond manual audit — acceptable for Solo, but the team needs an explicit dogfood checklist instead of SaaS dashboards.

---

## 7. Lessons learned

1. **Separate “site live” from “product launched.”** A Worker 200 does not mean Gatekeeper-safe install or security claims are shippable.
2. **For a no-telemetry product, define non-SaaS KPIs early** (notarize date, dogfood N, support threads, brew installs via tap analytics if any, LS order count) or post-launch reviews will always look empty.
3. **Security findings must land on main before marketing hard-launch.** Same-day fixes are good; uncommitted fixes are not a release.
4. **Keep Luna prerequisite reports** (deploy / monitor / test) even for Workers — otherwise `/ll-postlaunch` is forced into soft-launch mode every time.
5. **Threat model and PRODUCT copy must move together** when storage architecture changes (file vault vs Keychain narrative).

---

## 8. Recommendations — next 30 days

### Immediate (release blockers)

1. Commit security remediations in reviewable slices (master key wrap, MCP revoke-only, import default, cache invalidation, copy alignment).
2. Re-run or supersede code review on the committed tree; clear C1/C2/M1/M2 before any notarized build marketed as Keychain-rooted.
3. Developer ID sign → notarize → staple → publish DMG; tag `v0.1.0` only when that binary matches the security story.
4. Align PRODUCT, landing, Worker public HTML, and CHANGELOG with the real storage model.
5. Write the missing `.luna/vibe-vault/{deployment,monitoring-observability,test-validation}-report.md` stubs from this soft launch so the next review has a baseline.

### Short-term (weeks 2–3)

6. Push Homebrew formula; submit Cursor Directory draft; post LAUNCH_PACK when DMG is Gatekeeper-clean.
7. Address M3 (provider token protection) and expand EncryptedVaultStore / VaultService read-path tests to the CLAUDE critical bar.
8. Authenticate Cloudflare Observability (or export Worker analytics weekly) for the **marketing site only**.
9. Lemon Squeezy: confirm webhook → VV1 email path end-to-end with one real test order (no secret values in chat/logs).

### Longer (through day 30)

10. Dogfood protocol: N internal users, weekly audit-log spot checks, migrate-from-Keychain path exercised on a real machine.
11. Decide public messaging for Solo (free forever) vs Team upsell without in-app chrome.
12. Schedule a **true** post-launch review at launch+7 days after notarized tag — with deploy/monitor/test reports attached.

---

## 9. KPIs to track once truly launched

Track these only after notarized `v0.1.0` (or explicit public soft-launch date). Prefer **privacy-preserving** signals.

### Marketing Worker

| KPI | Source |
|-----|--------|
| Requests / day, 4xx/5xx rate, p95 latency | Cloudflare Analytics / `wrangler tail` samples |
| `/` vs `/api/checkout` vs `/download` traffic | CF path metrics |
| Checkout starts (Team/Studio/Company) | Lemon Squeezy dashboard (orders), not invented funnel % |
| Webhook success / failure | Worker logs (order id only; never license private key / secret values) |

### Native product (no Solo RUM)

| KPI | Source |
|-----|--------|
| Notarized DMG download count | Host (lunaos.ai / GitHub Releases) |
| Homebrew installs | Tap analytics / `brew` download stats if available |
| Support / Discord / GitHub issues (severity, ACL, MCP) | Issue tracker qualitative + volume |
| Dogfood: secrets managed, migrate completed, MCP allowlist used | Manual weekly survey / internal notes |
| Team licenses activated | Offline: count of support “activated” threads or LS fulfilled orders |
| Security regressions | Re-run `/ll-review` + SAST + gitleaks on each release candidate |

### Explicit non-KPIs (do not fake)

- App DAU/MAU, session length, feature funnel inside the macOS app  
- “AI agent engagement” from the cloud  
- Uptime % without monitoring report  

---

## 10. Follow-up

| When | Action |
|------|--------|
| After security commits land | Fresh code review / security pass; update this file’s “remediation” status |
| At notarized `v0.1.0` | Mark **public launch date**; start 7-day clock |
| Launch + 7 days | Full `/ll-postlaunch` with deploy + monitor + test reports and CF analytics (auth’d) |
| Launch + 30 days | Revisit KPIs above; decide PH / broader GTM |

---

## Sources

- `.luna/vibe-vault/requirements.md`, `implementation-plan.md`, `code-review-report.md`
- `.luna/vibe-vault/gtm/plan.md`, `gtm/feature-report.md`
- `.luna/vibe-vault/lemonsqueezy/feature-report.md`
- `PRODUCT.md`, `CLAUDE.md`, `CHANGELOG.md`
- Live spot checks: `vibevault.lunaos.ai` `/`, `/health`, `/api/checkout`, `/download` (2026-07-18)
- Git: `62ca9bb` (2026-07-18 GTM/Worker ship); working tree uncommitted security work; no local `v*` tags
- `scripts/gtm-check.sh` (0 fail, 2 warn)
- Cloudflare Observability MCP: **not used** (`needsAuth`)

---

*End of soft-launch post-launch review. No user counts, conversion rates, or uptime percentages were fabricated.*
