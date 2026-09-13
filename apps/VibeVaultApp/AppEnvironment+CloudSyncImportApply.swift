import Foundation
import VaultCore

extension AppEnvironment {
    func importCloudSyncSnapshot(
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
