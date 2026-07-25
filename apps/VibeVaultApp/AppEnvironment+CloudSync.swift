import Foundation
import VaultCore

struct AppCloudSyncStatus: Equatable {
    let localCount: Int
    let path: String
    let bundleExists: Bool
    let sizeText: String
    let modifiedText: String
}

struct AppCloudSyncPreview: Equatable {
    let path: String
    let sourceHost: String
    let exportedAtText: String
    let secretCount: Int
    let sizeText: String
}

extension AppEnvironment {
    func cloudSyncStatus() -> AppCloudSyncStatus {
        let url = CloudSync.defaultICloudURL()
        let attrs = try? FileManager.default.attributesOfItem(atPath: url.path)
        let size = (attrs?[.size] as? NSNumber)?.int64Value ?? 0
        let modified = attrs?[.modificationDate] as? Date
        return AppCloudSyncStatus(
            localCount: secrets.count,
            path: url.path,
            bundleExists: FileManager.default.fileExists(atPath: url.path),
            sizeText: size > 0 ? ByteCountFormatter.string(fromByteCount: size, countStyle: .file) : "-",
            modifiedText: modified?.formatted(date: .abbreviated, time: .shortened) ?? "-"
        )
    }

    func pushCloudSync(passphrase: String) async -> Bool {
        await pushCloudSync(to: CloudSync.defaultICloudURL(), passphrase: passphrase, destinationName: "iCloud")
    }

    func pushCloudSync(to url: URL, passphrase: String, destinationName: String) async -> Bool {
        do {
            let snapshot = try await cloudSyncSnapshot()
            let data = try CloudSync.encrypt(snapshot, passphrase: passphrase)
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
        await pullCloudSync(from: CloudSync.defaultICloudURL(), passphrase: passphrase, overwrite: overwrite, sourceName: "iCloud")
    }

    func pullCloudSync(from url: URL, passphrase: String, overwrite: Bool, sourceName: String) async -> Bool {
        do {
            let data = try Data(contentsOf: url)
            let snapshot = try CloudSync.decrypt(data, passphrase: passphrase)
            let result = try importCloudSyncSnapshot(snapshot, overwrite: overwrite)
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
        let data = try Data(contentsOf: url)
        let snapshot = try CloudSync.decrypt(data, passphrase: passphrase)
        return AppCloudSyncPreview(
            path: url.path,
            sourceHost: snapshot.sourceHost,
            exportedAtText: snapshot.exportedAt.formatted(date: .abbreviated, time: .shortened),
            secretCount: snapshot.secrets.count,
            sizeText: ByteCountFormatter.string(fromByteCount: Int64(data.count), countStyle: .file)
        )
    }

    private func cloudSyncSnapshot() async throws -> CloudSyncSnapshot {
        let names = try service.list().map(\.name).sorted()
        var items: [CloudSyncSecret] = []
        for name in names {
            let secret = try await service.read(name: name, reason: "Export \(name) for encrypted cloud sync")
            items.append(CloudSyncSecret(secret: secret))
        }
        return CloudSyncSnapshot(secrets: items)
    }

    private func importCloudSyncSnapshot(
        _ snapshot: CloudSyncSnapshot,
        overwrite: Bool
    ) throws -> (imported: Int, updated: Int, skipped: Int) {
        var imported = 0
        var updated = 0
        var skipped = 0
        for item in snapshot.secrets {
            if try service.store.exists(name: item.name) {
                guard overwrite else {
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
                    createdAt: item.createdAt
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
                    createdAt: item.createdAt
                )
                imported += 1
            }
        }
        return (imported: imported, updated: updated, skipped: skipped)
    }
}
