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
