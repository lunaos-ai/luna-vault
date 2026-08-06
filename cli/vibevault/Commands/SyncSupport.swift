import ArgumentParser
import Darwin
import Foundation
import VaultCore

func syncURL(path: String?) -> URL {
    if let path, !path.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
        return URL(fileURLWithPath: path).standardizedFileURL
    }
    return CloudSync.defaultICloudURL()
}

enum SyncSnapshotBuilder {
    static func snapshot() async throws -> CloudSyncSnapshot {
        let service = try VaultService.live()
        let names = try service.list().map(\.name).sorted()
        var secrets: [CloudSyncSecret] = []
        for name in names {
            let secret = try await service.read(name: name, reason: "Export \(name) for encrypted cloud sync")
            secrets.append(CloudSyncSecret(secret: secret))
        }
        let authenticatorService = try AuthenticatorService(vaultService: service)
        return CloudSyncSnapshot(
            secrets: secrets,
            revisions: try service.revisionsForEncryptedBackup(),
            authenticatorAccounts: try await authenticatorService.accountsForEncryptedBackup(),
            authenticatorRevisions: try authenticatorService.revisionsForEncryptedBackup()
        )
    }
}

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

enum SyncDecryptCredential {
    case passphrase(String)
    case recoveryKey(String)

    func decrypt(_ data: Data) throws -> CloudSyncSnapshot {
        switch self {
        case .passphrase(let passphrase):
            return try CloudSync.decrypt(data, passphrase: passphrase)
        case .recoveryKey(let recoveryKey):
            return try CloudSync.decrypt(data, recoveryKey: recoveryKey)
        }
    }

    static func resolve(
        passphraseEnv: String?,
        passphraseStdin: Bool,
        recoveryKeyEnv: String?,
        recoveryKeyStdin: Bool
    ) throws -> SyncDecryptCredential {
        let usesPassphraseOption = passphraseEnv != nil || passphraseStdin
        let usesRecoveryOption = recoveryKeyEnv != nil || recoveryKeyStdin
        guard !(usesPassphraseOption && usesRecoveryOption) else {
            throw ValidationError("choose either passphrase options or recovery-key options")
        }
        if let recoveryKeyEnv {
            guard let value = ProcessInfo.processInfo.environment[recoveryKeyEnv], !value.isEmpty else {
                throw ValidationError("recovery-key environment variable is empty")
            }
            return .recoveryKey(try CloudRecoveryKey.canonicalize(value))
        }
        if recoveryKeyStdin {
            let value = isatty(STDIN_FILENO) == 1
                ? try SyncPassphrase.readHiddenLine(prompt: "Recovery key: ")
                : readLine()
            guard let value, !value.isEmpty else {
                throw ValidationError("no recovery key provided on stdin")
            }
            return .recoveryKey(try CloudRecoveryKey.canonicalize(value))
        }
        return .passphrase(try SyncPassphrase.resolve(envName: passphraseEnv, stdin: passphraseStdin))
    }
}

enum SyncRecoveryKey {
    static func encryptionKey(envName: String?) throws -> String? {
        if let envName {
            guard let value = ProcessInfo.processInfo.environment[envName], !value.isEmpty else {
                throw ValidationError("recovery-key environment variable is empty")
            }
            return try CloudRecoveryKey.canonicalize(value)
        }
        let prefs = KeychainPrefs()
        guard let data = prefs.data(forKey: CloudRecoveryKey.preferenceKey),
              let value = String(data: data, encoding: .utf8),
              !value.isEmpty else {
            return nil
        }
        return try CloudRecoveryKey.canonicalize(value)
    }
}

struct SyncImportResult {
    var imported: [String] = []
    var updated: [String] = []
    var skipped: [String] = []
    var failed: [(String, String)] = []
}

enum SyncPassphrase {
    static func resolve(envName: String?, stdin: Bool, confirm: Bool = false) throws -> String {
        if let envName, let value = ProcessInfo.processInfo.environment[envName], !value.isEmpty {
            return value
        }
        if stdin {
            guard let line = readLine(), !line.isEmpty else {
                throw ValidationError("no passphrase provided on stdin")
            }
            return line
        }
        let first = try readHiddenLine(prompt: "Sync passphrase: ")
        guard confirm else { return first }
        let second = try readHiddenLine(prompt: "Confirm sync passphrase: ")
        guard first == second else { throw ValidationError("sync passphrases did not match") }
        return first
    }

    static func readHiddenLine(prompt: String) throws -> String {
        guard isatty(STDIN_FILENO) == 1 else {
            throw ValidationError("use --passphrase-stdin or --passphrase-env in non-interactive shells")
        }
        FileHandle.standardError.write(Data(prompt.utf8))
        var original = termios()
        guard tcgetattr(STDIN_FILENO, &original) == 0 else {
            throw ValidationError("could not configure terminal input")
        }
        var hidden = original
        hidden.c_lflag &= ~UInt(ECHO)
        tcsetattr(STDIN_FILENO, TCSANOW, &hidden)
        defer {
            tcsetattr(STDIN_FILENO, TCSANOW, &original)
            FileHandle.standardError.write(Data("\n".utf8))
        }
        guard let line = readLine(), !line.isEmpty else {
            throw ValidationError("empty sync passphrase")
        }
        return line
    }
}
