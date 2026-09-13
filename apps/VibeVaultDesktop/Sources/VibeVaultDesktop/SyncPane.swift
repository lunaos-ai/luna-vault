import Foundation
import SwiftCrossUI
import VaultCore

struct SyncPane: View {
    @Binding var model: DesktopModel
    var onRefresh: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Encrypted export / import")
                .font(.system(size: 18, weight: .semibold))
            Text(
                "Move secrets between Mac and Windows with a passphrase-protected .vvsync file. Passphrase must be at least 12 characters."
            )
            .foregroundColor(.gray)
            TextField("Path to .vvsync", text: $model.syncPath)
            TextField("Passphrase", text: $model.syncPassphrase)
            HStack(spacing: 8) {
                Button("Export") { Task { await exportVault() } }
                Button("Import") { Task { await importVault() } }
            }
            Spacer()
        }
        .padding(8)
    }

    private func exportVault() async {
        do {
            let url = try resolvedURL()
            let snapshot = try await DesktopSync.snapshot()
            let data = try CloudSync.encrypt(snapshot, passphrase: model.syncPassphrase)
            try CloudSync.write(data, to: url)
            model.statusMessage = "Exported to \(url.path)"
            model.errorMessage = nil
            onRefresh()
        } catch {
            model.errorMessage = error.localizedDescription
        }
    }

    private func importVault() async {
        do {
            let url = try resolvedURL()
            let snapshot = try CloudSync.decrypt(
                Data(contentsOf: url),
                passphrase: model.syncPassphrase
            )
            let count = try await DesktopSync.importSnapshot(snapshot, overwrite: model.syncOverwrite)
            model.statusMessage = "Imported \(count) secrets"
            model.errorMessage = nil
            onRefresh()
        } catch {
            model.errorMessage = error.localizedDescription
        }
    }

    private func resolvedURL() throws -> URL {
        let path = model.syncPath.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !path.isEmpty else {
            throw SecretError.vaultIO("set a .vvsync file path")
        }
        return URL(fileURLWithPath: path)
    }
}

enum DesktopSync {
    static func snapshot() async throws -> CloudSyncSnapshot {
        let service = try DesktopVault.service()
        let names = try service.list().map(\.name).sorted()
        var secrets: [CloudSyncSecret] = []
        for name in names {
            let secret = try await service.read(name: name, reason: "Export \(name)")
            secrets.append(CloudSyncSecret(secret: secret))
        }
        let authenticator = try AuthenticatorService(vaultService: service)
        return CloudSyncSnapshot(
            secrets: secrets,
            revisions: try service.revisionsForEncryptedBackup(),
            authenticatorAccounts: try await authenticator.accountsForEncryptedBackup(),
            authenticatorRevisions: try authenticator.revisionsForEncryptedBackup()
        )
    }

    static func importSnapshot(_ snapshot: CloudSyncSnapshot, overwrite: Bool) async throws -> Int {
        let service = try DesktopVault.service()
        var imported = 0
        for item in snapshot.secrets {
            let exists = (try? service.list().contains { $0.name == item.name }) ?? false
            if exists {
                guard overwrite else { continue }
                try service.update(
                    name: item.name, value: item.value, notes: item.notes,
                    expiresAt: item.expiresAt, rotateEveryDays: item.rotateEveryDays,
                    lastRotatedAt: item.lastRotatedAt,
                    mcpAllowed: item.mcpAllowed, totpAuthURL: item.totpAuthURL,
                    createdAt: item.createdAt, updatedAt: item.updatedAt,
                    revisionAction: .synced
                )
            } else {
                try service.add(
                    name: item.name, value: item.value, notes: item.notes,
                    expiresAt: item.expiresAt, rotateEveryDays: item.rotateEveryDays,
                    lastRotatedAt: item.lastRotatedAt,
                    mcpAllowed: item.mcpAllowed, totpAuthURL: item.totpAuthURL,
                    createdAt: item.createdAt, updatedAt: item.updatedAt,
                    revisionAction: .synced
                )
            }
            imported += 1
        }
        return imported
    }
}
