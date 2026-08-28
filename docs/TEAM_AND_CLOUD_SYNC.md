# Team License And Cloud Sync

Two separate features. Solo includes the full vault, MCP, providers, and encrypted sync. Team is optional paid-seat licensing. Cloud Sync does not require Team.

## Team license (purchase to activate)

### What Team is

- **Solo**: free, full product on one Mac.
- **Team / Studio / Company**: paid seats for small teams. Same app; an offline license key unlocks the Team badge and seat count.
- **Not included**: a hosted LunaOS vault, shared cloud account, or automatic seat enforcement across Macs.

### End-to-end purchase flow

1. Open **Settings → Team license** (or run `vibevault license status` for the checkout link).
2. Select **Buy Team**. Your browser opens Lemon Squeezy checkout (`vibevault.lunaos.ai/#pricing` by default, or a direct variant URL if configured).
3. Complete payment. Lemon Squeezy sends a webhook to `vibevault.lunaos.ai`.
4. The worker signs a **VV1** license key (35-day renewal on subscription events) and emails it when Resend is configured.
5. Paste the key in **Settings → Team license → License key**, or run:

```bash
vibevault license activate 'VV1.…'
vibevault license status
```

6. Verification is **offline** against an embedded public key. The app never phones home to check the license.

### What the key contains

- Purchaser email, seat count, tier (`team` = 5, `studio` = 20, `company` = 100), order id, optional expiry.
- Format: `VV1.<base64-payload>.<base64-signature>`.

### Renewal and refunds

- Subscription renewals issue fresh keys before the previous one expires.
- Refunds do not revoke keys already on a Mac before their signed expiry. Treat keys like offline software licenses.

### Operator checklist

- `GET https://vibevault.lunaos.ai/api/checkout` should return `"configured": true` with Team/Studio/Company URLs.
- Webhook: `POST /webhooks/lemonsqueezy` with `VIBEVAULT_LICENSE_PRIVATE_KEY` and `VIBEVAULT_WEBHOOK_SECRET`.
- Manual issue: `bash scripts/issue-license.sh --email … --seats 5 --order-id …`.

---

## Cloud Sync and backups (setup on each Mac)

Cloud Sync is **encrypted, user-controlled sync**. There is no Vibe Vault cloud account. Apple iCloud Drive (or a `.vvsync` file you copy) carries the ciphertext.

### Three related workflows

| Workflow | Purpose | Where it lives |
|----------|---------|----------------|
| **iCloud sync** | Keep one encrypted head bundle in sync between Macs | `~/Library/Mobile Documents/…/VibeVault/Sync/vault.vvsync` |
| **Manual backup** | Portable file for another Mac, external drive, or offline archive | Any path you choose (`.vvsync`) |
| **Managed backup history** | Timestamped snapshots with retention | `VibeVault/Sync/Backups` in iCloud Drive |

All three use the same encryption. They differ in destination and whether Vibe Vault stores your passphrase.

### Prerequisites (every Mac)

1. Sign in to your **Apple Account** in macOS System Settings.
2. Turn on **iCloud Drive**.
3. In Vibe Vault, open **Cloud Sync** and select **Refresh** until the route shows **This Mac → Encrypted → iCloud Drive**.

### Passphrase rules

- Minimum **12 characters**.
- Enter it twice (sync + confirm fields).
- **Manual sync and one-off exports**: passphrase is **not saved**. You must remember it or use a recovery key.
- **Scheduled backups**: selecting **Enable schedule** stores that passphrase in this Mac's Keychain so backups can run while the app is open.

### Recommended first-time setup

**On your primary Mac**

1. Open **Cloud Sync**.
2. Create a **recovery key** (recommended). Save the printable key outside this Mac (password manager or paper).
3. Enter and confirm a sync passphrase.
4. Select **Sync to iCloud** to publish the encrypted bundle.
5. Optional: set backup frequency and retention, then **Enable schedule** (requires the passphrase above).

**On a second Mac**

1. Complete Apple Account / iCloud Drive setup and **Refresh**.
2. Wait for `vault.vvsync` to appear in iCloud Drive (same Apple ID).
3. Enter the **same sync passphrase** (or use **Restore with recovery key** if you lost the passphrase).
4. Select **Preview iCloud** → review secret count and export date.
5. Select **Import from iCloud**. Default import policy: **Use newer** for matching names.

**For offline or cross-account moves**

1. On the source Mac: **Export encrypted backup…** → save `.vvsync`.
2. Copy the file (AirDrop, USB, etc.).
3. On the destination Mac: **Import encrypted backup…** → preview → import.

### What runs automatically

- **Scheduled backups** check at vault unlock and hourly while Vibe Vault is **open** and the session is **unlocked**.
- They do **not** run after you quit the app (no LaunchAgent yet).
- Menu bar shows last managed backup time when scheduling is on.

### Recovery quick reference

| Problem | Fix |
|---------|-----|
| Lost sync passphrase | Use **Restore with recovery key** if the bundle was protected with one |
| Lost recovery key | Original passphrase still works; create a new recovery key and fresh backups |
| Lost Keychain master key | Restore `~/Library/Application Support/vibe-vault` from Time Machine, then `vibevault recovery restore --recovery-key-stdin` |
| Two Macs both push without importing | Latest push wins on `vault.vvsync`; use managed backup history or local revision history to recover |

### CLI equivalents

```bash
vibevault sync status
vibevault sync push --to icloud
vibevault sync pull --from icloud --overwrite
vibevault sync export --path ~/Backups/vault.vvsync
vibevault sync import --path ~/Backups/vault.vvsync --overwrite
vibevault sync backup --retain 30
vibevault sync history
vibevault sync recovery-key --install
vibevault recovery status
```

See also: `docs/CLOUD_SYNC_AND_BACKUP.md` for security model, import policies, and edge cases.

### UI smoke test

Automated app walkthrough (Cloud Sync screen → Settings Team license):

```bash
vibevault session unlock   # optional; required for iCloud push in smoke
bash scripts/tests/cloud-sync-team-ui-smoke.sh
```

Results: `/tmp/vibevault-ui-smoke-result.json` and screenshot in `/tmp/vibevault-ui-smoke-shots/`.
