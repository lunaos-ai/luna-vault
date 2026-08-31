import Foundation
import VaultCore

private enum AppCloudSyncCredential {
    case passphrase(String)
    case recoveryKey(String)
    case keyring
}

extension AppEnvironment {
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

    func pullCloudSyncUsingKeyring(
        from url: URL,
        policy: AppCloudSyncImportPolicy,
        sourceName: String
    ) async -> Bool {
        await pullCloudSync(
            from: url,
            credential: .keyring,
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
            let result = try await importCloudSyncSnapshot(snapshot, policy: policy)
            refresh()
            showToast("Imported \(result.imported + result.updated) vault items from \(sourceName)")
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

    func previewCloudSyncBundleUsingKeyring(at url: URL) throws -> AppCloudSyncPreview {
        try previewCloudSyncBundle(at: url, credential: .keyring)
    }

    private func previewCloudSyncBundle(
        at url: URL,
        credential: AppCloudSyncCredential
    ) throws -> AppCloudSyncPreview {
        let data = try Data(contentsOf: url)
        let snapshot = try decryptCloudSync(data, credential: credential)
        let info = try CloudSync.inspect(data)
        let comparison = CloudSyncInspector.compare(snapshot: snapshot, localSecrets: try service.list())
        return AppCloudSyncPreview(
            path: url.path,
            sourceHost: snapshot.sourceHost,
            exportedAtText: snapshot.exportedAt.formatted(date: .abbreviated, time: .shortened),
            createdAtText: info.createdAt.formatted(date: .abbreviated, time: .shortened),
            secretCount: snapshot.secrets.count,
            revisionCount: snapshot.revisions.count,
            authenticatorCount: snapshot.authenticatorAccounts.count,
            sizeText: ByteCountFormatter.string(fromByteCount: Int64(data.count), countStyle: .file),
            newCount: comparison.newNames.count,
            backupNewerCount: comparison.backupNewerNames.count,
            localNewerCount: comparison.localNewerNames.count,
            sameTimestampCount: comparison.sameTimestampNames.count,
            hasRecoveryProtection: info.hasRecoveryProtection,
            recoveryFingerprint: info.recoveryFingerprint,
            isLegacyRecovery: info.isLegacyRecovery,
            matchingKeyStatus: loadedRecoveryKeyring().matchStatus(for: info)
        )
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
        case .keyring:
            return try CloudSync.decrypt(data, keyring: loadedRecoveryKeyring())
        }
    }

    func cloudSyncSnapshot() async throws -> CloudSyncSnapshot {
        let names = try service.list().map(\.name).sorted()
        var items: [CloudSyncSecret] = []
        for name in names {
            let secret = try await service.read(name: name, reason: "Export \(name) for encrypted cloud sync")
            items.append(CloudSyncSecret(secret: secret))
        }
        return CloudSyncSnapshot(
            secrets: items,
            revisions: try service.revisionsForEncryptedBackup(),
            authenticatorAccounts: try await authenticatorService.accountsForEncryptedBackup(),
            authenticatorRevisions: try authenticatorService.revisionsForEncryptedBackup()
        )
    }
}
