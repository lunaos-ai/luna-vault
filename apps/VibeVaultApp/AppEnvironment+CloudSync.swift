import AppKit
import Foundation
import VaultCore

struct AppCloudSyncStatus: Equatable {
    let localCount: Int
    let path: String
    let iCloudRootPath: String
    let iCloudAvailable: Bool
    let bundleExists: Bool
    let sizeText: String
    let modifiedText: String
}

struct AppCloudSyncPreview: Equatable {
    let path: String
    let sourceHost: String
    let exportedAtText: String
    let secretCount: Int
    let revisionCount: Int
    let sizeText: String
    let newCount: Int
    let backupNewerCount: Int
    let localNewerCount: Int
    let sameTimestampCount: Int
}

enum AppCloudSyncImportPolicy: String, CaseIterable, Identifiable {
    case keepLocal
    case backupNewer
    case replaceAll

    var id: String { rawValue }

    var label: String {
        switch self {
        case .keepLocal: return "Keep local"
        case .backupNewer: return "Use newer"
        case .replaceAll: return "Replace all"
        }
    }
}

private enum AppCloudSyncCredential {
    case passphrase(String)
    case recoveryKey(String)
}

extension AppEnvironment {
    static let automaticBackupPassphraseKey = "cloud-backup-passphrase"
    static let backupRecoveryKeyKey = CloudRecoveryKey.preferenceKey

    func cloudSyncStatus() -> AppCloudSyncStatus {
        let url = CloudSync.defaultICloudURL()
        let rootURL = CloudSync.iCloudDriveRootURL()
        let attrs = try? FileManager.default.attributesOfItem(atPath: url.path)
        let size = (attrs?[.size] as? NSNumber)?.int64Value ?? 0
        let modified = attrs?[.modificationDate] as? Date
        return AppCloudSyncStatus(
            localCount: secrets.count,
            path: url.path,
            iCloudRootPath: rootURL.path,
            iCloudAvailable: CloudSync.isICloudDriveAvailable(at: rootURL),
            bundleExists: FileManager.default.fileExists(atPath: url.path),
            sizeText: size > 0 ? ByteCountFormatter.string(fromByteCount: size, countStyle: .file) : "-",
            modifiedText: modified?.formatted(date: .abbreviated, time: .shortened) ?? "-"
        )
    }

    func pushCloudSync(passphrase: String) async -> Bool {
        guard cloudSyncStatus().iCloudAvailable else {
            showToast("Enable iCloud Drive in System Settings", feedback: .caution)
            return false
        }
        return await pushCloudSync(
            to: CloudSync.defaultICloudURL(),
            passphrase: passphrase,
            destinationName: "iCloud"
        )
    }

    func openAppleAccountSettings() {
        let candidates = [
            "x-apple.systempreferences:com.apple.systempreferences.AppleIDSettings",
            "x-apple.systempreferences:com.apple.preferences.icloud"
        ]
        for candidate in candidates {
            guard let url = URL(string: candidate) else { continue }
            if NSWorkspace.shared.open(url) { return }
        }
        NSWorkspace.shared.open(
            URL(fileURLWithPath: "/System/Applications/System Settings.app")
        )
    }

    func openICloudDrive() {
        let status = cloudSyncStatus()
        guard status.iCloudAvailable else {
            showToast("iCloud Drive is not available on this Mac", feedback: .caution)
            return
        }
        let bundleURL = CloudSync.defaultICloudURL()
        let target = FileManager.default.fileExists(atPath: bundleURL.path)
            ? bundleURL
            : CloudSync.iCloudDriveRootURL()
        NSWorkspace.shared.activateFileViewerSelecting([target])
    }

    func pushCloudSync(to url: URL, passphrase: String, destinationName: String) async -> Bool {
        do {
            let snapshot = try await cloudSyncSnapshot()
            let data = try CloudSync.encrypt(
                snapshot,
                passphrase: passphrase,
                recoveryKey: backupRecoveryKey()
            )
            try CloudSync.write(data, to: url)
            showToast("Synced \(snapshot.secrets.count) secrets to \(destinationName)")
            return true
        } catch {
            lastError = "\(error)"
            showToast("Cloud sync failed", feedback: .caution)
            return false
        }
    }

    func pullCloudSync(passphrase: String, overwrite: Bool) async -> Bool {
        await pullCloudSync(
            from: CloudSync.defaultICloudURL(),
            passphrase: passphrase,
            policy: overwrite ? .replaceAll : .keepLocal,
            sourceName: "iCloud"
        )
    }

    func pullCloudSync(from url: URL, passphrase: String, overwrite: Bool, sourceName: String) async -> Bool {
        await pullCloudSync(
            from: url,
            passphrase: passphrase,
            policy: overwrite ? .replaceAll : .keepLocal,
            sourceName: sourceName
        )
    }

    func pullCloudSync(
        from url: URL,
        passphrase: String,
        policy: AppCloudSyncImportPolicy,
        sourceName: String
    ) async -> Bool {
        await pullCloudSync(
            from: url,
            credential: .passphrase(passphrase),
            policy: policy,
            sourceName: sourceName
        )
    }

    func pullCloudSync(
        from url: URL,
        recoveryKey: String,
        policy: AppCloudSyncImportPolicy,
        sourceName: String
    ) async -> Bool {
        await pullCloudSync(
            from: url,
            credential: .recoveryKey(recoveryKey),
            policy: policy,
            sourceName: sourceName
        )
    }

    private func pullCloudSync(
        from url: URL,
        credential: AppCloudSyncCredential,
        policy: AppCloudSyncImportPolicy,
        sourceName: String
    ) async -> Bool {
        do {
            let data = try Data(contentsOf: url)
            let snapshot = try decryptCloudSync(data, credential: credential)
            let result = try importCloudSyncSnapshot(snapshot, policy: policy)
            refresh()
            showToast("Imported \(result.imported + result.updated) secrets from \(sourceName)")
            return true
        } catch {
            lastError = "\(error)"
            showToast("Cloud import failed", feedback: .caution)
            return false
        }
    }

    func previewCloudSyncBundle(at url: URL, passphrase: String) throws -> AppCloudSyncPreview {
        try previewCloudSyncBundle(at: url, credential: .passphrase(passphrase))
    }

    func previewCloudSyncBundle(at url: URL, recoveryKey: String) throws -> AppCloudSyncPreview {
        try previewCloudSyncBundle(at: url, credential: .recoveryKey(recoveryKey))
    }

    private func previewCloudSyncBundle(
        at url: URL,
        credential: AppCloudSyncCredential
    ) throws -> AppCloudSyncPreview {
        let data = try Data(contentsOf: url)
        let snapshot = try decryptCloudSync(data, credential: credential)
        let comparison = CloudSyncInspector.compare(snapshot: snapshot, localSecrets: try service.list())
        return AppCloudSyncPreview(
            path: url.path,
            sourceHost: snapshot.sourceHost,
            exportedAtText: snapshot.exportedAt.formatted(date: .abbreviated, time: .shortened),
            secretCount: snapshot.secrets.count,
            revisionCount: snapshot.revisions.count,
            sizeText: ByteCountFormatter.string(fromByteCount: Int64(data.count), countStyle: .file),
            newCount: comparison.newNames.count,
            backupNewerCount: comparison.backupNewerNames.count,
            localNewerCount: comparison.localNewerNames.count,
            sameTimestampCount: comparison.sameTimestampNames.count
        )
    }

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
        let encoded = Data(canonical.utf8)
        prefs.set(encoded, forKey: Self.backupRecoveryKeyKey)
        guard prefs.data(forKey: Self.backupRecoveryKeyKey) == encoded else {
            throw SecretError.vaultIO("could not store recovery key in macOS Keychain")
        }
        cachedHasBackupRecoveryKey = true
        showToast("Recovery protection enabled")
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

    private func backupRecoveryKey() -> String? {
        guard let data = prefs.data(forKey: Self.backupRecoveryKeyKey),
              let value = String(data: data, encoding: .utf8),
              !value.isEmpty else {
            return nil
        }
        return value
    }

    private func decryptCloudSync(
        _ data: Data,
        credential: AppCloudSyncCredential
    ) throws -> CloudSyncSnapshot {
        switch credential {
        case .passphrase(let passphrase):
            return try CloudSync.decrypt(data, passphrase: passphrase)
        case .recoveryKey(let recoveryKey):
            return try CloudSync.decrypt(data, recoveryKey: recoveryKey)
        }
    }

    private func cloudSyncSnapshot() async throws -> CloudSyncSnapshot {
        let names = try service.list().map(\.name).sorted()
        var items: [CloudSyncSecret] = []
        for name in names {
            let secret = try await service.read(name: name, reason: "Export \(name) for encrypted cloud sync")
            items.append(CloudSyncSecret(secret: secret))
        }
        return CloudSyncSnapshot(
            secrets: items,
            revisions: try service.revisionsForEncryptedBackup()
        )
    }

    private func importCloudSyncSnapshot(
        _ snapshot: CloudSyncSnapshot,
        policy: AppCloudSyncImportPolicy
    ) throws -> (imported: Int, updated: Int, skipped: Int) {
        var imported = 0
        var updated = 0
        var skipped = 0
        let localByName = Dictionary(uniqueKeysWithValues: try service.list().map { ($0.name, $0) })
        for item in snapshot.secrets {
            if let local = localByName[item.name] {
                let shouldUpdate: Bool
                switch policy {
                case .keepLocal:
                    shouldUpdate = false
                case .backupNewer:
                    shouldUpdate = item.updatedAt.timeIntervalSince(local.updatedAt) > 1
                case .replaceAll:
                    shouldUpdate = true
                }
                guard shouldUpdate else {
                    skipped += 1
                    continue
                }
                try service.update(
                    name: item.name,
                    value: item.value,
                    notes: item.notes,
                    expiresAt: item.expiresAt,
                    rotateEveryDays: item.rotateEveryDays,
                    lastRotatedAt: item.lastRotatedAt,
                    mcpAllowed: item.mcpAllowed,
                    totpAuthURL: item.totpAuthURL,
                    createdAt: item.createdAt,
                    updatedAt: item.updatedAt,
                    revisionAction: .synced
                )
                updated += 1
            } else {
                try service.add(
                    name: item.name,
                    value: item.value,
                    notes: item.notes,
                    expiresAt: item.expiresAt,
                    rotateEveryDays: item.rotateEveryDays,
                    lastRotatedAt: item.lastRotatedAt,
                    mcpAllowed: item.mcpAllowed,
                    totpAuthURL: item.totpAuthURL,
                    createdAt: item.createdAt,
                    updatedAt: item.updatedAt,
                    revisionAction: .synced
                )
                imported += 1
            }
        }
        try service.mergeRevisionsFromEncryptedBackup(snapshot.revisions)
        return (imported: imported, updated: updated, skipped: skipped)
    }
}
