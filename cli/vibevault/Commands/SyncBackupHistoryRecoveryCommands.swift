import ArgumentParser
import Foundation
import VaultCore

struct SyncBackupCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "backup",
        abstract: "Create a timestamped encrypted iCloud backup and apply retention."
    )

    @Option(name: .long, help: "Backup directory. Defaults to VibeVault/Sync/Backups in iCloud Drive.")
    var directory: String?

    @Option(name: .long, help: "Number of managed backups to retain.")
    var retain = 30

    @Option(name: .long, help: "Read passphrase from this environment variable.")
    var passphraseEnv: String?

    @Flag(name: .long, help: "Read passphrase from stdin.")
    var passphraseStdin = false

    @Option(name: .long, help: "Read an optional recovery key from this environment variable; otherwise use the configured Keychain key.")
    var recoveryKeyEnv: String?

    mutating func run() async throws {
        guard retain > 0 else { throw ValidationError("--retain must be at least 1") }
        guard directory != nil || CloudSync.isICloudDriveAvailable() else {
            throw ValidationError("iCloud Drive is unavailable; sign in or enable it in System Settings")
        }
        let snapshot = try await SyncSnapshotBuilder.snapshot()
        let passphrase = try SyncPassphrase.resolve(
            envName: passphraseEnv,
            stdin: passphraseStdin,
            confirm: true
        )
        let data = try CloudSync.encrypt(
            snapshot,
            passphrase: passphrase,
            recoveryKey: SyncRecoveryKey.encryptionKey(envName: recoveryKeyEnv)
        )
        let target = directory.map {
            URL(fileURLWithPath: $0, isDirectory: true).standardizedFileURL
        } ?? CloudBackupArchive.defaultICloudDirectory()
        let result = try CloudBackupArchive.write(data, to: target, retentionCount: retain)
        print("backed up \(snapshot.secrets.count) secrets to \(result.backup.url.path)")
        print("retention removed: \(result.removed.count)")
    }
}

struct SyncHistoryCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "history",
        abstract: "List timestamped encrypted backups."
    )

    @Option(name: .long, help: "Backup directory. Defaults to VibeVault/Sync/Backups in iCloud Drive.")
    var directory: String?

    mutating func run() throws {
        let target = directory.map {
            URL(fileURLWithPath: $0, isDirectory: true).standardizedFileURL
        } ?? CloudBackupArchive.defaultICloudDirectory()
        let backups = try CloudBackupArchive.list(in: target)
        print("backup directory: \(target.path)")
        print("backups: \(backups.count)")
        for backup in backups {
            let date = ISO8601DateFormatter().string(from: backup.createdAt)
            let size = ByteCountFormatter.string(fromByteCount: backup.size, countStyle: .file)
            print("\(date)  \(size)  \(backup.url.lastPathComponent)")
        }
    }
}

struct SyncRecoveryKeyCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "recovery-key",
        abstract: "Generate a printable backup recovery key."
    )

    @Flag(name: .long, help: "Store the generated key in this Mac's Keychain for future backups.")
    var install = false

    mutating func run() throws {
        let key = try CloudRecoveryKey.generate()
        if install {
            let prefs = KeychainPrefs()
            let encoded = Data(key.utf8)
            prefs.set(encoded, forKey: CloudRecoveryKey.preferenceKey)
            guard prefs.data(forKey: CloudRecoveryKey.preferenceKey) == encoded else {
                throw ValidationError("could not store recovery key in macOS Keychain")
            }
            print("installed recovery key in this Mac's Keychain")
        }
        print(key)
        FileHandle.standardError.write(Data("Store this key separately from encrypted backups; it cannot be recovered.\n".utf8))
    }
}
