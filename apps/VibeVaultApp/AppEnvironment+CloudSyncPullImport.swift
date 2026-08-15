import Foundation
import VaultCore

private enum AppCloudSyncCredential {
    case passphrase(String)
    case recoveryKey(String)
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
            authenticatorCount: snapshot.authenticatorAccounts.count,
            sizeText: ByteCountFormatter.string(fromByteCount: Int64(data.count), countStyle: .file),
            newCount: comparison.newNames.count,
            backupNewerCount: comparison.backupNewerNames.count,
            localNewerCount: comparison.localNewerNames.count,
            sameTimestampCount: comparison.sameTimestampNames.count
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

    private func importCloudSyncSnapshot(
        _ snapshot: CloudSyncSnapshot,
        policy: AppCloudSyncImportPolicy
    ) async throws -> (imported: Int, updated: Int, skipped: Int) {
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
        let authResult = try await authenticatorService.importAccounts(
            snapshot.authenticatorAccounts,
            duplicatePolicy: policy == .replaceAll ? .replace : .skip
        )
        try authenticatorService.mergeRevisionsFromEncryptedBackup(
            snapshot.authenticatorRevisions
        )
        imported += authResult.imported.count
        updated += authResult.replaced.count
        skipped += authResult.skipped.count
        return (imported: imported, updated: updated, skipped: skipped)
    }
}
