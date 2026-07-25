# Vibe Vault Cloud Sync And Backup

Vibe Vault supports encrypted, user-controlled sync bundles for moving a local vault between Macs and for creating restorable backups. The current implementation does not use a hosted Vibe Vault account or server-side key escrow.

## What Exists Today

- iCloud Drive sync bundle at `~/Library/Mobile Documents/com~apple~CloudDocs/Documents/VibeVault/Sync/vault.vvsync`.
- Manual encrypted backup export to any `.vvsync` file.
- Manual encrypted backup import from any `.vvsync` file.
- Restore preview in the macOS app before importing a selected bundle.
- CLI support for status, push, pull, export, and import.
- Snapshot coverage for secret values, notes, creation/update metadata, rotation metadata, AI-access flags, and attached MFA setup URLs.

## Security Model

- Bundles are encrypted locally before writing to iCloud Drive or a backup file.
- Encryption uses AES-256-GCM.
- Key derivation uses PBKDF2-SHA256 followed by HKDF-SHA256.
- Current KDF iteration count is 600,000.
- The sync passphrase must be at least 12 characters.
- The sync passphrase is never stored by Vibe Vault.
- Files are written atomically and permissions are set to `0600`.
- Recovery requires both the encrypted bundle and the sync passphrase.

## macOS App Flow

Open **Settings -> Cloud Sync**.

To sync through iCloud Drive:

1. Enter a sync passphrase and confirm it.
2. Select **Sync to iCloud** on the source Mac.
3. Wait for iCloud Drive to finish syncing `vault.vvsync`.
4. On the destination Mac, enter the same passphrase.
5. Select **Preview iCloud** to verify source Mac, export date, secret count, and size.
6. Select **Import from iCloud**.

To create a manual backup:

1. Enter and confirm a sync passphrase.
2. Select **Export backup...**.
3. Save the `.vvsync` bundle to the chosen location.
4. Store the passphrase separately from the backup file.

To restore a manual backup:

1. Enter the backup passphrase.
2. Select **Choose backup...**.
3. Review the preview metadata.
4. Enable **Overwrite matching names on import** only when the backup should replace local values with the same names.
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
```

For automation, pass the sync passphrase through an environment variable or stdin:

```bash
vibevault sync export --path ~/Backups/vault.vvsync --passphrase-env VIBEVAULT_SYNC_PASSPHRASE
vibevault sync import --path ~/Backups/vault.vvsync --passphrase-stdin
```

## Current Limits

- Backups are manual; scheduled automatic backups are not implemented yet.
- There is no backup history or retention policy UI yet.
- There is no multi-device merge UI yet.
- If two Macs update the same secret, the current import behavior is skip or overwrite.
- There is no hosted LunaOS web vault, account sync service, or server-side key recovery.

## Future Work

- Scheduled encrypted backups.
- Backup history and retention policy.
- Last-sync status in the menu bar.
- Conflict detection and per-secret merge UI.
- Optional local backup folder monitoring.
- Team and enterprise policy controls for backup destinations and retention.
