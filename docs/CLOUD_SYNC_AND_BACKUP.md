# Vibe Vault Cloud Sync And Backup

Vibe Vault supports encrypted, user-controlled sync bundles for moving a local vault between Macs and for creating restorable backups. The current implementation does not use a hosted Vibe Vault account or server-side key escrow.

## What Exists Today

- iCloud Drive sync bundle at `~/Library/Mobile Documents/com~apple~CloudDocs/Documents/VibeVault/Sync/vault.vvsync`.
- Manual encrypted backup export to any `.vvsync` file.
- Manual encrypted backup import from any `.vvsync` file.
- Restore preview in the macOS app before importing a selected bundle.
- Timestamped encrypted backup history under `VibeVault/Sync/Backups` in iCloud Drive.
- Configurable retention from 1 to 100 managed backups.
- Opt-in scheduled backups while the app is open and the vault session is unlocked.
- Metadata-based restore comparison for new names, backup-newer names, local-newer names, and matching timestamps.
- Import policies to keep local values, use the newer bundle value, or replace all matching names.
- CLI support for status, push, pull, export, import, preview, backup, and history.
- Snapshot coverage for secret values, notes, creation/update metadata, rotation metadata, AI-access flags, and attached MFA setup URLs.
- Encrypted per-secret version history, retained up to 50 revisions per secret.
- Automatic encrypted rollback copy before the first legacy-vault schema migration (`secrets.vault.pre-versioning-v1`).
- Single-secret preview and restore from the secret detail screen.
- Recently Deleted recovery for names whose latest local revision is a deletion.
- Optional printable recovery key for restoring a protected bundle when its passphrase is unavailable.
- Local master-key recovery protection for restoring a Keychain key after Keychain loss or Mac migration.

## Security Model

- Bundles are encrypted locally before writing to iCloud Drive or a backup file.
- Bundle format v2 encrypts each snapshot with a new random 256-bit data key using AES-256-GCM.
- The data key is wrapped independently by the sync passphrase and, when configured, the recovery key.
- Key derivation uses PBKDF2-SHA256 followed by HKDF-SHA256.
- Current KDF iteration count is 600,000.
- Recovery keys contain 256 random bits and use HKDF-SHA256 before wrapping the data key.
- The sync passphrase must be at least 12 characters.
- Manual sync passphrases are never stored by Vibe Vault.
- Enabling scheduled backups stores that passphrase in macOS Keychain with `WhenUnlockedThisDeviceOnly` access. Disabling the schedule removes it.
- A configured recovery key is stored only in this Mac's Keychain with `WhenUnlockedThisDeviceOnly` access so scheduled and CLI backups can include recovery protection.
- The same recovery key wraps a copy of the local vault master key in `master-key.vvrecovery`. The raw master key is never stored in the vault database or beside its ciphertext.
- `secrets.vault`, `master-key.vvrecovery`, and their containing directory remain eligible for Time Machine backup. The recovery key must be saved separately from that backup.
- Recovery keys are not uploaded separately, synced through a Vibe Vault account, or escrowed by LunaOS.
- Files are written atomically and permissions are set to `0600`.
- Vibe Vault can still decrypt existing v1 passphrase-only bundles.
- Recovery requires the encrypted bundle and either its passphrase or a recovery key that protected that bundle.

## macOS App Flow

Select **Cloud Sync** in the main sidebar.

Vibe Vault uses the Apple Account configured in macOS. It does not implement a separate Apple login or receive Apple credentials:

1. If iCloud Drive is unavailable, select **Sign in to Apple Account**.
2. Sign in or enable iCloud Drive in System Settings.
3. Return to Vibe Vault and select **Refresh**.
4. Confirm the route shows **This Mac -> Encrypted -> iCloud Drive**.

To sync through iCloud Drive:

1. Enter a sync passphrase and confirm it.
2. Select **Sync to iCloud** on the source Mac.
3. Wait for iCloud Drive to finish syncing `vault.vvsync`.
4. On the destination Mac, enter the same passphrase.
5. Select **Preview iCloud** to verify source Mac, export date, secret count, and size.
6. Select **Import from iCloud**.

The **Sync to iCloud** action is enabled after iCloud Drive is available and the sync passphrase has been entered and confirmed.

To create a manual backup:

1. Enter and confirm a sync passphrase.
2. Select **Export backup...**.
3. Save the `.vvsync` bundle to the chosen location.
4. Store the passphrase separately from the backup file.

To configure recovery protection:

1. Select **Create recovery key**.
2. Copy the key or export the recovery kit.
3. Select **I saved this key** to store it in this Mac's Keychain.
4. Vibe Vault immediately protects the local vault master key for Keychain-loss recovery.
5. Create a new backup or select **Sync to iCloud**. Existing bundles are not changed retroactively.
6. On another Mac, enter the same key under **Restore with recovery key** and select **Use for future backups** if that Mac should protect its new bundles with the same key.

Replacing a recovery key affects new backups only. Keep an old recovery key until every backup protected by it has expired from retention or been replaced.

After upgrading, the app also creates the local recovery envelope automatically when a recovery key was already configured on that Mac.

To enable managed backup history:

1. Enter and confirm a passphrase.
2. Choose a frequency and retention count.
3. Select **Enable schedule**.
4. Unlock Vibe Vault for the session when the app starts.

The app checks for an overdue backup at unlock and hourly afterward. The schedule runs only while Vibe Vault is open; it does not install a system LaunchAgent.

To restore a manual backup:

1. Enter the backup passphrase.
2. Select **Choose backup...**.
3. Review the preview metadata.
4. Choose **Keep local**, **Use newer**, or **Replace all** for matching names.
5. Select **Import selected**.

To restore one secret version:

1. Open the secret in **Vault**.
2. Expand **Version history**.
3. Select a saved version and authenticate.
4. Preview its value and metadata.
5. Select **Restore this version**. The current value remains in history as another revision.

To restore a deleted secret, select the trash button in the Vault toolbar, open the deleted revision, and restore it. Local history retains at most 50 revisions per secret.

## CLI Flow

```bash
# Check local vault count and iCloud bundle status.
vibevault sync status

# Mac A: write encrypted sync bundle to iCloud Drive.
vibevault sync push --to icloud

# Mac B: import it after iCloud Drive syncs the file.
vibevault sync pull --from icloud --overwrite

# Export an encrypted backup bundle to a chosen file.
vibevault sync export --path ~/Backups/vault.vvsync

# Import an encrypted backup bundle from a chosen file.
vibevault sync import --path ~/Backups/vault.vvsync --overwrite

# Compare a bundle with the local vault without importing.
vibevault sync preview --path ~/Backups/vault.vvsync

# Create a timestamped iCloud backup and retain the newest 30.
vibevault sync backup --retain 30

# List timestamped backup history.
vibevault sync history

# Generate one key that protects the local master key and future backup bundles.
vibevault sync recovery-key --install

# Check local master-key recovery protection without opening the vault.
vibevault recovery status

# Restore a missing Keychain master key after restoring the Vibe Vault folder.
vibevault recovery restore --recovery-key-stdin

# Import only bundle entries newer than matching local entries.
vibevault sync import --path ~/Backups/vault.vvsync --newer-only
```

For CLI automation, pass the sync passphrase through a protected environment variable or stdin:

```bash
vibevault sync export --path ~/Backups/vault.vvsync --passphrase-env VIBEVAULT_SYNC_PASSPHRASE
vibevault sync import --path ~/Backups/vault.vvsync --passphrase-stdin

# Recover without the passphrase.
vibevault sync preview --path ~/Backups/vault.vvsync --recovery-key-env VIBEVAULT_RECOVERY_KEY
vibevault sync import --path ~/Backups/vault.vvsync --recovery-key-stdin --newer-only
```

Push, export, and backup commands automatically use the recovery key configured in this Mac's Vibe Vault Keychain. `--recovery-key-env` can supply an explicit key instead.

## Recovery Scenarios

### Lost or reset macOS Keychain

Restore `~/Library/Application Support/vibe-vault` from Time Machine if it is missing, then run `vibevault recovery status`. If `secrets.vault` and `master-key.vvrecovery` are present, run `vibevault recovery restore --recovery-key-stdin` and enter the separately saved printable recovery key. Vibe Vault authenticates the existing ciphertext before writing the restored key to Keychain. A wrong key makes no Keychain change.

If the recovery envelope was never created, use a retained `.vvsync` backup and its passphrase or recovery key. The encrypted local vault cannot be decrypted from `secrets.vault` alone.

### Lost sync passphrase

If the bundle was created after recovery protection was configured, expand **Restore with recovery key**, enter the saved recovery key, preview the bundle, and import it. CLI users can pass `--recovery-key-env` or `--recovery-key-stdin`.

If the bundle has no recovery wrapper, one Mac must still have a readable local vault so a new backup can be created with a new passphrase. There is no server-side escrow.

### Lost recovery key

The original passphrase can still decrypt the bundle. Generate a replacement recovery key and create fresh backups. Replacing the key does not re-encrypt existing backup history.

### Lost passphrase and recovery key

If one Mac still has the working local vault, create a fresh backup with new credentials immediately. If no readable local vault remains, Vibe Vault cannot decrypt the backups; rotate the affected credentials at each provider and rebuild the vault.

### Lost or deleted bundle

If a source Mac still has the local vault, create a new backup immediately. Otherwise, restore the newest retained `.vvsync` file from iCloud Drive recovery, another backup destination, or device backup, then preview it before importing.

### Replacing a Mac

Install Vibe Vault on the new Mac, make the encrypted bundle available through iCloud Drive or external storage, enter the original passphrase or recovery key, preview the contents and saved-version count, and import with **Use newer** as the default policy. Keep the old Mac unchanged until the secret count and critical provider credentials have been verified.

### Recovery testing

Periodically run `vibevault recovery status`, export a fresh bundle, preview it with `vibevault sync preview`, and verify that the expected secret count and source timestamp are present. A preview validates decryption and bundle integrity without changing the local vault. Keep the printable recovery key in a password manager or offline recovery kit, not only in the same Mac's Keychain.

## Current Limits

- Scheduled app backups do not run after the Vibe Vault process exits.
- The scheduler requires the local vault to be unlocked for the app session.
- There is no per-secret multi-device merge UI yet.
- Revision history is bounded to 50 encrypted revisions per secret and is not an unlimited archive.
- History preserves changes that reach a vault or imported bundle, but there is no dedicated side-by-side merge UI for simultaneous edits to the same secret.
- Pushing from two Macs without importing the other Mac's latest bundle first can still overwrite the shared `vault.vvsync` head. Managed backup history and each Mac's local revisions remain the recovery sources.
- There is no hosted LunaOS web vault, account sync service, or server-side key recovery.

## Future Work

- Optional LaunchAgent-based scheduling for backups while the app is not running.
- Per-secret side-by-side merge UI for divergent versions.
- Optional monitored backup folder outside the managed iCloud directory.
- Team and enterprise policy controls for backup destinations and retention.
