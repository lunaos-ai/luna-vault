import ArgumentParser
import Foundation
import VaultCore

enum SyncImporter {
    static func importSnapshot(
        from url: URL,
        credential: SyncDecryptCredential,
        overwrite: Bool,
        newerOnly: Bool = false
    ) async throws {
        let snapshot = try credential.decrypt(Data(contentsOf: url))
        let service = try VaultService.live()
        let localByName = Dictionary(uniqueKeysWithValues: try service.list().map { ($0.name, $0) })
        var result = SyncImportResult()

        for item in snapshot.secrets {
            do {
                try upsert(
                    item,
                    into: service,
                    local: localByName[item.name],
                    overwrite: overwrite,
                    newerOnly: newerOnly,
                    result: &result
                )
                try service.recordEvent(name: item.name, action: .importEvent, projectPath: service.currentProjectPath())
            } catch {
                result.failed.append((item.name, "\(error)"))
            }
        }
        try service.mergeRevisionsFromEncryptedBackup(snapshot.revisions)
        let authenticatorService = try AuthenticatorService(vaultService: service)
        let authResult = try await authenticatorService.importAccounts(
            snapshot.authenticatorAccounts,
            duplicatePolicy: overwrite ? .replace : .skip
        )
        try authenticatorService.mergeRevisionsFromEncryptedBackup(
            snapshot.authenticatorRevisions
        )

        print("imported \(result.imported.count), updated \(result.updated.count), skipped \(result.skipped.count), failed \(result.failed.count)")
        print("authenticators imported \(authResult.imported.count), replaced \(authResult.replaced.count), skipped \(authResult.skipped.count)")
        print("source: \(snapshot.sourceHost) at \(ISO8601DateFormatter().string(from: snapshot.exportedAt))")
        for failure in result.failed {
            FileHandle.standardError.write(Data("failed \(failure.0): \(failure.1)\n".utf8))
        }
        if !result.failed.isEmpty { throw ExitCode(4) }
    }

    private static func upsert(
        _ item: CloudSyncSecret,
        into service: VaultService,
        local: Secret?,
        overwrite: Bool,
        newerOnly: Bool,
        result: inout SyncImportResult
    ) throws {
        if let local {
            let shouldUpdate = overwrite
                || (newerOnly && item.updatedAt.timeIntervalSince(local.updatedAt) > 1)
            guard shouldUpdate else {
                result.skipped.append(item.name)
                return
            }
            try update(item, in: service)
            result.updated.append(item.name)
        } else {
            try add(item, to: service)
            result.imported.append(item.name)
        }
    }

    private static func update(_ item: CloudSyncSecret, in service: VaultService) throws {
        try service.update(
            name: item.name, value: item.value, notes: item.notes,
            expiresAt: item.expiresAt, rotateEveryDays: item.rotateEveryDays,
            lastRotatedAt: item.lastRotatedAt,
            mcpAllowed: item.mcpAllowed, totpAuthURL: item.totpAuthURL,
            createdAt: item.createdAt, updatedAt: item.updatedAt,
            revisionAction: .synced
        )
    }

    private static func add(_ item: CloudSyncSecret, to service: VaultService) throws {
        try service.add(
            name: item.name, value: item.value, notes: item.notes,
            expiresAt: item.expiresAt, rotateEveryDays: item.rotateEveryDays,
            lastRotatedAt: item.lastRotatedAt,
            mcpAllowed: item.mcpAllowed, totpAuthURL: item.totpAuthURL,
            createdAt: item.createdAt, updatedAt: item.updatedAt,
            revisionAction: .synced
        )
    }
}
