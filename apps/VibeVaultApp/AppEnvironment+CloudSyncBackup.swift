import Foundation
import VaultCore

extension AppEnvironment {
    func managedCloudBackups() -> [CloudBackupFile] {
        do {
            return try CloudBackupArchive.list()
        } catch {
            lastError = "\(error)"
            return []
        }
    }

    func enableAutomaticCloudBackups(passphrase: String) -> Bool {
        guard passphrase.count >= 12 else {
            showToast("Use a passphrase with at least 12 characters", feedback: .caution)
            return false
        }
        prefs.set(Data(passphrase.utf8), forKey: Self.automaticBackupPassphraseKey)
        cachedHasAutomaticBackupCredential = true
        automaticBackupsEnabled = true
        showToast("Automatic backups enabled")
        return true
    }

    func generateBackupRecoveryKey() throws -> String {
        try CloudRecoveryKey.generate()
    }

    func saveBackupRecoveryKey(_ recoveryKey: String) throws {
        let canonical = try CloudRecoveryKey.canonicalize(recoveryKey)
        try LocalVaultRecovery.protect(
            directory: EncryptedVaultStore.defaultDirectory(),
            recoveryKey: canonical
        )
        let encoded = Data(canonical.utf8)
        prefs.set(encoded, forKey: Self.backupRecoveryKeyKey)
        guard prefs.data(forKey: Self.backupRecoveryKeyKey) == encoded else {
            throw SecretError.vaultIO("could not store recovery key in macOS Keychain")
        }
        cachedHasBackupRecoveryKey = true
        showToast("Recovery protection enabled")
    }

    func ensureLocalRecoveryProtection() {
        let directory = EncryptedVaultStore.defaultDirectory()
        guard !LocalVaultRecovery.isProtected(directory: directory),
              let recoveryKey = backupRecoveryKey() else { return }
        do {
            try LocalVaultRecovery.protect(
                directory: directory,
                recoveryKey: recoveryKey
            )
        } catch {
            lastError = "Could not enable local vault recovery: \(error)"
        }
    }

    func revealBackupRecoveryKey() async throws -> String {
        try await service.biometric.authenticate(reason: "Show the Vibe Vault recovery key")
        guard let key = backupRecoveryKey() else {
            throw CloudSyncError.recoveryUnavailable
        }
        return key
    }

    func removeBackupRecoveryKey() {
        prefs.set(nil, forKey: Self.backupRecoveryKeyKey)
        cachedHasBackupRecoveryKey = false
        showToast("Recovery protection removed from future backups", feedback: .tick)
    }

    func disableAutomaticCloudBackups() {
        automaticBackupsEnabled = false
        prefs.set(nil, forKey: Self.automaticBackupPassphraseKey)
        cachedHasAutomaticBackupCredential = false
        showToast("Automatic backups disabled", feedback: .tick)
    }

    func createManagedCloudBackup(passphrase: String, showFeedback: Bool = true) async -> Bool {
        guard cloudSyncStatus().iCloudAvailable else {
            if showFeedback {
                showToast("Enable iCloud Drive before creating a managed backup", feedback: .caution)
            }
            return false
        }
        do {
            let snapshot = try await cloudSyncSnapshot()
            let data = try CloudSync.encrypt(
                snapshot,
                passphrase: passphrase,
                recoveryKey: backupRecoveryKey()
            )
            let result = try CloudBackupArchive.write(
                data,
                retentionCount: backupRetentionCount
            )
            lastManagedBackupAt = result.backup.createdAt
            if showFeedback {
                showToast("Saved encrypted backup with \(snapshot.secrets.count) secrets")
            }
            return true
        } catch {
            lastError = "\(error)"
            if showFeedback {
                showToast("Backup failed", feedback: .caution)
            }
            return false
        }
    }

    func runManagedCloudBackupNow(passphrase: String?) async -> Bool {
        let resolved = passphrase ?? automaticCloudBackupPassphrase()
        guard let resolved, !resolved.isEmpty else {
            showToast("Enter a backup passphrase", feedback: .caution)
            return false
        }
        return await createManagedCloudBackup(passphrase: resolved)
    }

    func updateBackupSchedulerState() {
        if automaticBackupsEnabled, cachedHasAutomaticBackupCredential {
            backupScheduler.start(intervalHours: backupIntervalHours)
        } else {
            backupScheduler.stop()
        }
    }

    func pruneManagedCloudBackups() {
        do {
            let removed = try CloudBackupArchive.prune(keeping: backupRetentionCount)
            showToast(
                removed.isEmpty ? "Backup retention is up to date" : "Removed \(removed.count) old backups",
                feedback: .tick
            )
        } catch {
            lastError = "\(error)"
            showToast("Could not apply backup retention", feedback: .caution)
        }
    }

    func automaticBackupCredentialAvailable() -> Bool {
        cachedHasAutomaticBackupCredential
    }

    func runScheduledCloudBackup() async -> Bool {
        guard automaticBackupsEnabled, sessionUnlocked else { return false }
        guard let passphrase = automaticCloudBackupPassphrase() else {
            cachedHasAutomaticBackupCredential = false
            automaticBackupsEnabled = false
            return false
        }
        return await createManagedCloudBackup(passphrase: passphrase, showFeedback: false)
    }

    private func automaticCloudBackupPassphrase() -> String? {
        guard let data = prefs.data(forKey: Self.automaticBackupPassphraseKey),
              let value = String(data: data, encoding: .utf8),
              !value.isEmpty else {
            return nil
        }
        return value
    }

    func backupRecoveryKey() -> String? {
        guard let data = prefs.data(forKey: Self.backupRecoveryKeyKey),
              let value = String(data: data, encoding: .utf8),
              !value.isEmpty else {
            return nil
        }
        return value
    }

}
