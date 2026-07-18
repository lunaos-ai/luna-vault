# Vibe Vault — Project Code Review Report

**Date:** 2026-07-18
**Scope:** Project-level (`/ll-review`) — uncommitted working tree on `main` + shipped 0.1 GTM baseline
**Reviewer:** Luna Code Review (Auto)
**Artifacts used:** `PRODUCT.md`, `DESIGN.md`, `CLAUDE.md`, `AGENTS.md`, `.luna/vibe-vault/*/plan.md` + feature-reports
**Note:** Formal `.luna/vibe-vault/{implementation-plan,design,requirements}.md` are **missing**. This review substitutes the product docs above.

---

## Executive summary

The recent work is well engineered and fixes real pain: the Keychain ACL password-sheet spam is replaced by an encrypted file vault with lazy migration, license forgery is hardened (raw key re-verified, not payload-trusted), the MCP server now shares the same store as App/CLI, provider Setup sheets are wired, import gains rename/prefix, and the MCP binary resolver finds the bundled helper. LOC discipline holds (largest changed file `VaultService.swift` at 175 non-blank lines; every changed Swift file ≤ 200). The license Ed25519 verify path and the Cloudflare Worker webhook (HMAC + offline Ed25519 signing) are sound and leak no secrets.

Two themes block a clean release:

1. **Trust-model drift (Critical).** Product copy and `CLAUDE.md` still say secrets live in the macOS Keychain, but the live store is `~/Library/Application Support/vibe-vault/secrets.vault` encrypted with a **plaintext `master.key` (mode `0600`) sitting in the same directory**. Any code running as the user can read the key and decrypt the vault; the app-layer `BiometricGate` is not a barrier to filesystem access.

2. **AI-access boundary is softer than the docs imply (Major).** The MCP `set_mcp_allowed` tool lets a connected agent grant itself read access to any secret, and bulk import defaults `allowForAI` to **on**. The per-secret allowlist — the product's central "human decides what AI sees" control — is therefore convenience-gated, not a hard confidentiality boundary. Provider API tokens are also stored under an intentionally-open Keychain ACL with no biometric gate.

**Verdict: APPROVE WITH CHANGES.** Solo dogfood and continued development are fine. Do not notarize a public 0.1 that markets "Keychain-backed secrets," and tighten the AI-access defaults/boundary before GTM.

---

## Findings

### Critical

| ID | Location | Finding | Recommendation |
|----|----------|---------|----------------|
| C1 | `VaultFileCrypto.swift:19-34`, `EncryptedVaultStore.swift:20-23,78-83` | The 32-byte AES-GCM master key is generated with `SecRandomCopyBytes` and written straight to `master.key` (`0o600`) in the **same directory** as `secrets.vault`. At-rest "encryption" is defeated for any same-user process (malware, a compromised MCP host, Time Machine / cloud-synced Application Support). Touch ID (`BiometricGate`) is app-layer only and is fully bypassed by reading the two files directly. | Store the master key in the Keychain (`kSecAttrAccessibleWhenUnlockedThisDeviceOnly`, ideally a biometric/SE-backed ACL) or derive it from a Secure Enclave key. Keep only ciphertext on disk. |
| C2 | `PRODUCT.md:25`, `CLAUDE.md` ("Local-first via macOS Keychain"), `marketing/landing/index.html`, `workers/vibevault/public/index.html` | Public + internal docs claim Keychain as the secret store while runtime uses the file vault (`VaultService.live()` → `MigratingVaultStore` → `EncryptedVaultStore`). Misleading security posture for buyers/auditors. | Either restore Keychain as root of trust for the master key (C1) **or** rewrite the copy to "encrypted local vault, Touch ID gated." Do not ship GTM claiming "Keychain storage" until aligned. |

### Major

| ID | Location | Finding | Recommendation |
|----|----------|---------|----------------|
| M1 | `cli/vibevault-mcp/MCPTools.swift:33-44,85,130-135` + `cli/vibevault-mcp/VibeVaultMCP.swift:19` + `VaultService.swift:88-98` | **Allowlist self-bypass.** The MCP server runs with `NoopBiometricGate`, and `set_mcp_allowed` is an exposed tool. An agent that wants a currently-blocked secret can call `set_mcp_allowed(name, true)` then `read_secret(name)` — no human in the loop. The `mcpAllowed` gate in `readSecret` (`MCPTools.swift:119`) is therefore only a speed bump, not a boundary. The audit log records it after the fact, but confidentiality is already gone. | Do not let the MCP surface flip `mcpAllowed` to `true`. Make enabling AI access an **app-only** action (or require an interactive in-app confirmation / short TTL). Keep `set_mcp_allowed(false)` (revoke) available to agents; deny enable. |
| M2 | `apps/VibeVaultApp/Features/Vault/ImportReviewSheet.swift:20,156-158` | `@State private var allowForAI = true` — every import defaults to granting AI/MCP access to **all** imported secrets. For a security-first, "human decides" product this is a dangerous default and compounds M1. | Default `allowForAI = false`. Make AI exposure an explicit opt-in per import (or per row). |
| M3 | `packages/VaultCore/Sources/VaultCore/Providers/ProviderCredentialStore.swift:28-30`, `KeychainPrefs.swift:71-78` | High-value provider tokens (Cloudflare, Vercel — full read/write over the user's cloud env vars) are persisted through `KeychainPrefs`, which deliberately writes with an **open ACL** (`KeychainAccess.applyOpenAccess`). No biometric gate applies to token reads. Any same-user process can exfiltrate them. | Store provider tokens in the biometric-gated vault path (not open-ACL prefs), or wrap with the same protection recommended in C1. At minimum, document the exposure. |
| M4 | `TeamEntitlement.swift:14-20` vs app/CLI call sites | `TeamEntitlement.requireLicensed` is effectively unused outside tests/license status; seat counts and Team gating are not enforced on provider sync or MCP. If Solo is intentionally full-featured, license is cosmetic; if not, it is unenforced. | Decide the model. Document "Solo = full product; Team = seats/support" in PRODUCT, **or** gate seat-limited features via `requireLicensed`. |
| M5 | Coverage vs `CLAUDE.md` test matrix | `EncryptedVaultStore` + `VaultService.read` are now the secret read path, but the matrix still targets 100% line+branch on `KeychainStore`. New store tests are good but not exhaustive: no corrupt/wrong-length `master.key`, no AES-GCM tamper-fails-closed, no duplicate/`notFound` branches on the file store, and `MigratingVaultStore` lazy read-migration + `migrateAllFromKeychain` are untested. | Re-point the 100% critical-path bar at `EncryptedVaultStore`/`VaultService.read`; add corruption, tamper, and migration tests. |
| M6 | Whole working tree (`git status`) | A large, security-sensitive feature set (file vault, migration, provider Setup, license harden, MCP resolver, import UX) is entirely **uncommitted** on `main`. Hard to review, bisect, or ship safely. | Commit in logical slices (per the split-to-prs pattern) before any notarized build. |
| M7 | `VaultService.swift` `readCache` | After delete/rotate/update, in-memory `readCache` can still return old plaintext until lock/migrate. Long-lived MCP has its own cache. | Invalidate per-name (or full) cache on every mutating store op. |

### Minor

| ID | Location | Finding | Recommendation |
|----|----------|---------|----------------|
| m1 | `MCPTools.swift:140,167-172,156-165` | `scan_project`, `suggest_secrets_for_task`, and `get_audit_log` operate over `service.list()` / full audit history, so a connected agent can enumerate the **names** of secrets that are *not* MCP-allowed (values stay hidden). Small metadata leak vs the allowlist intent. | Filter these tools' name-comparison and audit output to `mcpAllowed` names, or document that names (not values) are visible to MCP. |
| m2 | `VaultService.swift:163-173` | Audit is recorded before return (good), but on the cache-hit branch the secret is already in `readCache`; if `audit.record` throws, the value stays cached while the caller sees an error. | On audit failure, evict the cache entry and rethrow — fail closed for the "audit cannot be bypassed" invariant. |
| m3 | `MigratingVaultStore.swift:51-54,57-61` | `exists` and `pendingLegacyCount` still call the legacy Keychain, which can reintroduce ACL sheets on hot paths. | Prefer file-only checks on hot paths; confine Keychain touches to the explicit Migrate action. |
| m4 | `KeychainAccess.swift:11-22` | The open-ACL helper weakens the OS ACL by design (documented for migration ergonomics). Acceptable for legacy read-heal; risky if any *new* sensitive write uses it (see M3). | Ensure new secret material never persists via open ACL; reserve it strictly for legacy read-heal. |
| m5 | `apps/VibeVaultApp/AppEnvironment.swift:31`, `Scenes/MainWindow.swift:46-50` | `openVercel` is declared and cleared but **never set to `true`** (unlike `openCloudflare`). Dead deep-link flag. | Wire an "Open Vercel" affordance or remove the flag. |
| m6 | Many `apps/**/*.swift` copy strings (e.g. `SessionTrustSection.swift`, `KeychainMigrationBanner.swift`, `OnboardingScene.swift`, `VaultHealth.swift`) | Em dashes (`—`) appear in UI copy; PRODUCT/DESIGN explicitly forbid em dashes in copy. | Replace with commas, colons, or periods. |
| m7 | `.luna/vibe-vault/` | Formal `implementation-plan.md`, `design.md`, `requirements.md` absent; future `/ll-*` runs have no canonical source. | Add stubs linking to PRODUCT/DESIGN/CLAUDE. |
| m8 | `scripts/bundle-app.sh`, `scripts/ensure-debug-codesign.sh` | Ad-hoc debug signing is expected for dev but keeps Keychain ACL painful and is not shippable. | Keep for debug; release must be Developer ID signed + notarized + stapled. |

---

## Security analysis

### Solid

- **Single read façade.** `VaultService.read` always calls `biometric.authenticate` then records the audit event before returning (`VaultService.swift:163-173`). Every mutating op also audits.
- **License forgery fixed.** `LicenseStore.load` re-verifies the stored VV1 raw key on every load; a tampered payload alone never grants Team (`LicenseStore.swift:9-26`). `LicenseCodec.verify` checks prefix, Ed25519 signature against the embedded public key, and expiry (`LicenseCodec.swift:30-46`). The private signing key is not embedded — it lives only in the Worker/CLI env.
- **Worker.** HMAC-SHA256 signature verification with a constant-time compare (`workers/vibevault/src/index.ts:178-197`), offline Ed25519 signing from a `wrangler secret`, no secret values logged (only `email/orderId/variant/seats`). `config.example.json` holds placeholders only.
- **AES-GCM** usage is correct (authenticated; tamper decrypts-fail via `AES.GCM.open`), and vault files are written `0o600` atomically. The *only* problem is key storage location (C1).
- **MCP read denial** for `mcpAllowed == false` works as written (`MCPTools.swift:119-123`); provider push filters to allowed names.

### Residual risks

1. **Same-user disk access** to `master.key` + `secrets.vault` (C1) — the dominant risk.
2. **Agent self-authorization** via `set_mcp_allowed` + Noop biometric (M1), amplified by import default (M2).
3. **Open-ACL provider tokens** readable without biometric (M3).
4. **Stale read cache** after delete/rotate (M7).
5. **Secret-name enumeration** through MCP scan/suggest/audit (m1).
6. Confirm on every release that Lock always runs `resetSession()` + `clearReadCache()` (verified today in `AppEnvironment+VaultOps.swift:57-65`).

---

## Requirements matrix (PRODUCT / CLAUDE)

| Requirement | Status | Notes |
|-------------|--------|-------|
| macOS 14+, SwiftUI + CLI + VaultCore | Met | |
| No 3rd-party deps in VaultCore (except CLI parser) | Met | CryptoKit / Security / sqlite3 system frameworks |
| `kSecAttrService = dev.vibevault` | Partial | Used for prefs + legacy Keychain; secrets moved to file vault |
| Secrets stored in Keychain (encrypted at rest) | **Gap** | File vault + plaintext master key (C1/C2) |
| Audit every read before return | Met | Via `VaultService` (see m2 caveat on cache-hit) |
| Biometric on every read (session window) | Met (App/CLI) | MCP intentionally Noop (M1) |
| MCP allowlist per secret (human opt-in) | **Partial** | Agent can self-grant (M1); import defaults on (M2) |
| Provider HTTPS + never log secret values | Met | Adapters + Setup sheet use `SecureField`, no value logging |
| Provider token storage protection | **Partial** | Open-ACL prefs, no biometric (M3) |
| LOC ≤ 200 / file | Met | Max changed file 175 lines |
| Coverage: 100% KeychainStore read / AuditDB write | Partial | Critical path shifted to `EncryptedVaultStore` (M5) |
| Solo offline / no telemetry / no phone-home | Met | |
| Team offline VV1 license | Met | Verify path fixed; enforcement weak (M4) |
| Calm Locksmith UI, accent for action only | Mostly | Em dashes in copy (m6) |
| Setup flows (CF / Vercel / PushCI) | Met | Sheets wired; smoke script present |

---

## Code quality

**Strengths**
- Clear façades (`VaultService`, `MigratingVaultStore`, `ProviderRegistry`) and small, focused files under the LOC cap.
- Good extraction (`ImportReviewControls`, `ProviderTokenSetupSheet`, `VaultListFilter`, `VaultBulkSelect`).
- `SecureField` + monospaced identifier styling in the token Setup sheet; no value logging.
- New tests for encrypted vault round-trip/persist, migration list/flag, license re-verify, and MCP binary candidates; `scripts/tests/setup-flows-smoke.sh` gives a repeatable regression.

**Gaps**
- Product/marketing copy not updated for the storage change (C2).
- Dead `openVercel` setter (m5); em dashes in copy (m6).
- Formal Luna plan files absent (m7).

## Performance

- `EncryptedVaultStore.loadAll()` decrypts the **entire** vault on every read/list/exists (`EncryptedVaultStore.swift:85-94`). Fine at solo scale; revisit (indexed/chunked format, or in-memory cache invalidated on write) if users exceed a few hundred secrets.
- `queue.sync` serialization is correct. Avoid calling `list()` / `pendingLegacyCount()` from SwiftUI `body`; the token/flag caching pattern already avoids most of this.

## Test gaps (priority)

1. Corrupt / wrong-length `master.key` → clear error, no crash (`VaultFileCrypto.swift:23-24`).
2. AES-GCM tamper → `read`/`loadAll` fails closed.
3. `MigratingVaultStore` lazy read-migration + `migrateAllFromKeychain` branches.
4. `VaultService.read` audit-failure evicts cache (m2).
5. MCP `read_secret` denied path and `set_mcp_allowed` policy (once M1 is fixed).

---

## Recommendations (ordered)

1. **Keychain/SE-wrap the master key** — closes C1.
2. **Align PRODUCT + landing copy** with the real storage model — closes C2.
3. **Remove agent-side allow-enable** (`set_mcp_allowed` → deny `true`) and **default import `allowForAI` to off** — M1, M2.
4. **Protect provider tokens** with the biometric-gated path — M3.
5. Commit the working tree in reviewable slices — M6.
6. Expand vault-store coverage to the CLAUDE critical-path bar — M5.
7. Filter MCP name-enumeration surfaces (m1); wire/remove `openVercel` (m5); strip em dashes (m6); add Luna plan stubs (m7).

### Example — Keychain-wrapped master key (sketch)

```swift
// Store the 32-byte key in the Keychain; the file holds ciphertext only.
let key = try KeychainMasterKey.loadOrCreate(
    service: "dev.vibevault",
    account: "vault.master",
    accessible: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
)
let blob = try VaultFileCrypto.seal(plain, key: key)
```

### Example — deny agent-side allow-enable

```swift
// MCPTools.setMCPAllowed
guard allowed == false else {
    return errorResult("Enabling AI access must be done in Vibe Vault. Agents may only revoke.")
}
try await context.service.setMCPAllowed(name: name, allowed: false)
```

---

## Approval

| Gate | Decision |
|------|----------|
| Security — at-rest model vs claims | **CHANGES REQUIRED** (C1, C2) |
| Security — AI access boundary | **CHANGES REQUIRED** (M1, M2, M3) |
| Functional Solo readiness | **GO** after copy/key-wrap or honest docs |
| Team license crypto | **GO** (re-verify + Ed25519 sound) |
| Provider / MCP setup UX | **GO** |
| Notarized public release | **NO-GO** until Developer ID build + C1/C2/M1/M2 addressed |

### Final status: **APPROVE WITH CHANGES**

Safe to continue Solo development and internal dogfood. **Not** ready to notarize or market a public 0.1 as "Keychain-backed secrets," and the AI-access defaults/boundary (M1, M2, M3) should be tightened before GTM, since they are the product's core differentiator.

---

## Prerequisites follow-up

Create for future `/ll-*` runs:

- `.luna/vibe-vault/implementation-plan.md` (mark vault migration, Setup sheets, license harden, MCP resolver `[x]`)
- `.luna/vibe-vault/requirements.md` → include PRODUCT + CLAUDE security table
- `.luna/vibe-vault/design.md` → include DESIGN.md

## Next step

```text
/luna-test
```

After fixing C1/C2 and the AI-access items (M1/M2/M3), or explicitly accepting and documenting the file-vault + agent-allow threat model.
