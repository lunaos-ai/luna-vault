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

## Security Model

- Bundles are encrypted locally before writing to iCloud Drive or a backup file.
- Encryption uses AES-256-GCM.
- Key derivation uses PBKDF2-SHA256 followed by HKDF-SHA256.
- Current KDF iteration count is 600,000.
- The sync passphrase must be at least 12 characters.
- Manual sync passphrases are never stored by Vibe Vault.
- Enabling scheduled backups stores that passphrase in macOS Keychain with `WhenUnlockedThisDeviceOnly` access. Disabling the schedule removes it.
- Files are written atomically and permissions are set to `0600`.
- Recovery requires both the encrypted bundle and the sync passphrase.

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

# Import only bundle entries newer than matching local entries.
vibevault sync import --path ~/Backups/vault.vvsync --newer-only
```

For CLI automation, pass the sync passphrase through a protected environment variable or stdin:

```bash
vibevault sync export --path ~/Backups/vault.vvsync --passphrase-env VIBEVAULT_SYNC_PASSPHRASE
vibevault sync import --path ~/Backups/vault.vvsync --passphrase-stdin
```

## Recovery Scenarios

### Lost sync passphrase

Vibe Vault cannot decrypt an existing bundle without its passphrase. There is no server-side recovery key or escrow. If one Mac still has the working local vault, create a new encrypted backup with a new passphrase. If no readable local vault remains, rotate the affected credentials at each provider and rebuild the vault.

### Lost or deleted bundle

If a source Mac still has the local vault, create a new backup immediately. Otherwise, restore the newest retained `.vvsync` file from iCloud Drive recovery, another backup destination, or device backup, then preview it before importing.

### Replacing a Mac

Install Vibe Vault on the new Mac, make the encrypted bundle available through iCloud Drive or external storage, enter the original passphrase, preview the contents, and import with **Use newer** as the default policy. Keep the old Mac unchanged until the secret count and critical provider credentials have been verified.

### Recovery testing

Periodically export a fresh bundle, preview it with `vibevault sync preview`, and verify that the expected secret count and source timestamp are present. A preview validates decryption and bundle integrity without changing the local vault.

## Current Limits

- Scheduled app backups do not run after the Vibe Vault process exits.
- The scheduler requires the local vault to be unlocked for the app session.
- There is no per-secret multi-device merge UI yet.
- Conflict handling uses update timestamps; it does not preserve two divergent values as separate versions.
- There is no hosted LunaOS web vault, account sync service, or server-side key recovery.

## Future Work

- Optional LaunchAgent-based scheduling for backups while the app is not running.
- Per-secret merge UI and divergent-version preservation.
- Optional monitored backup folder outside the managed iCloud directory.
- Team and enterprise policy controls for backup destinations and retention.
