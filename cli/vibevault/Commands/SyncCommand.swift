import ArgumentParser
import Foundation
import VaultCore

struct SyncCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "sync",
        abstract: "Encrypted cloud sync for moving a vault between Macs.",
        subcommands: [
            SyncStatusCommand.self,
            SyncPushCommand.self,
            SyncPullCommand.self,
            SyncExportCommand.self,
            SyncImportCommand.self,
            SyncPreviewCommand.self,
            SyncBackupCommand.self,
            SyncHistoryCommand.self,
            SyncRecoveryKeyCommand.self
        ]
    )
}

struct SyncStatusCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "status",
        abstract: "Show local vault and iCloud sync bundle status."
    )

    mutating func run() async throws {
        let service = try VaultService.live()
        let localCount = try service.list().count
        let cloudURL = CloudSync.defaultICloudURL()
        print("local secrets: \(localCount)")
        print("icloud drive: \(CloudSync.isICloudDriveAvailable() ? "available" : "unavailable")")
        print("icloud path: \(cloudURL.path)")
        let recoveryConfigured = KeychainPrefs().data(forKey: CloudRecoveryKey.preferenceKey) != nil
        print("recovery protection: \(recoveryConfigured ? "configured" : "not configured")")
        guard FileManager.default.fileExists(atPath: cloudURL.path) else {
            print("icloud bundle: missing")
            return
        }
        let attrs = try FileManager.default.attributesOfItem(atPath: cloudURL.path)
        let size = attrs[.size] as? NSNumber
        let modified = attrs[.modificationDate] as? Date
        print("icloud bundle: present")
        if let size { print("size: \(ByteCountFormatter.string(fromByteCount: size.int64Value, countStyle: .file))") }
        if let modified { print("modified: \(ISO8601DateFormatter().string(from: modified))") }
    }
}

struct SyncPushCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "push",
        abstract: "Encrypt and write the local vault snapshot to iCloud Drive."
    )

    @Option(name: .long, help: "Destination: icloud.")
    var to: String = "icloud"

    @Option(name: .long, help: "Override destination path.")
    var path: String?

    @Option(name: .long, help: "Read passphrase from this environment variable.")
    var passphraseEnv: String?

    @Flag(name: .long, help: "Read passphrase from stdin.")
    var passphraseStdin = false

    @Option(name: .long, help: "Read an optional recovery key from this environment variable; otherwise use the configured Keychain key.")
    var recoveryKeyEnv: String?

    mutating func run() async throws {
        guard to == "icloud" else { throw ValidationError("unsupported sync destination: \(to)") }
        guard path != nil || CloudSync.isICloudDriveAvailable() else {
            throw ValidationError("iCloud Drive is unavailable; sign in or enable it in System Settings")
        }
        let url = syncURL(path: path)
        let passphrase = try SyncPassphrase.resolve(envName: passphraseEnv, stdin: passphraseStdin, confirm: true)
        let snapshot = try await SyncSnapshotBuilder.snapshot()
        let data = try CloudSync.encrypt(
            snapshot,
            passphrase: passphrase,
            recoveryKey: SyncRecoveryKey.encryptionKey(envName: recoveryKeyEnv)
        )
        try CloudSync.write(data, to: url)
        print("synced \(snapshot.secrets.count) secrets to \(url.path)")
    }
}

struct SyncPullCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "pull",
        abstract: "Decrypt and import the iCloud Drive sync bundle."
    )

    @Option(name: .long, help: "Source: icloud.")
    var from: String = "icloud"

    @Option(name: .long, help: "Override source path.")
    var path: String?

    @Option(name: .long, help: "Read passphrase from this environment variable.")
    var passphraseEnv: String?

    @Flag(name: .long, help: "Read passphrase from stdin.")
    var passphraseStdin = false

    @Option(name: .long, help: "Read recovery key from this environment variable instead of a passphrase.")
    var recoveryKeyEnv: String?

    @Flag(name: .long, help: "Read recovery key from stdin instead of a passphrase.")
    var recoveryKeyStdin = false

    @Flag(name: .long, help: "Update local secrets when names already exist.")
    var overwrite = false

    @Flag(name: .long, help: "Update matching local secrets only when the bundle is newer.")
    var newerOnly = false

    mutating func run() async throws {
        guard from == "icloud" else { throw ValidationError("unsupported sync source: \(from)") }
        guard !(overwrite && newerOnly) else {
            throw ValidationError("--overwrite and --newer-only cannot be used together")
        }
        let url = syncURL(path: path)
        try await SyncImporter.importSnapshot(
            from: url,
            credential: SyncDecryptCredential.resolve(
                passphraseEnv: passphraseEnv,
                passphraseStdin: passphraseStdin,
                recoveryKeyEnv: recoveryKeyEnv,
                recoveryKeyStdin: recoveryKeyStdin
            ),
            overwrite: overwrite,
            newerOnly: newerOnly
        )
    }
}

struct SyncExportCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "export",
        abstract: "Write an encrypted vault sync bundle to a file."
    )

    @Option(name: .long, help: "Destination file path.")
    var path: String

    @Option(name: .long, help: "Read passphrase from this environment variable.")
    var passphraseEnv: String?

    @Flag(name: .long, help: "Read passphrase from stdin.")
    var passphraseStdin = false

    @Option(name: .long, help: "Read an optional recovery key from this environment variable; otherwise use the configured Keychain key.")
    var recoveryKeyEnv: String?

    mutating func run() async throws {
        let passphrase = try SyncPassphrase.resolve(envName: passphraseEnv, stdin: passphraseStdin, confirm: true)
        let snapshot = try await SyncSnapshotBuilder.snapshot()
        let data = try CloudSync.encrypt(
            snapshot,
            passphrase: passphrase,
            recoveryKey: SyncRecoveryKey.encryptionKey(envName: recoveryKeyEnv)
        )
        let url = URL(fileURLWithPath: path).standardizedFileURL
        try CloudSync.write(data, to: url)
        print("exported \(snapshot.secrets.count) secrets to \(url.path)")
    }
}

struct SyncImportCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "import",
        abstract: "Import an encrypted vault sync bundle from a file."
    )

    @Option(name: .long, help: "Source file path.")
    var path: String

    @Option(name: .long, help: "Read passphrase from this environment variable.")
    var passphraseEnv: String?

    @Flag(name: .long, help: "Read passphrase from stdin.")
    var passphraseStdin = false

    @Option(name: .long, help: "Read recovery key from this environment variable instead of a passphrase.")
    var recoveryKeyEnv: String?

    @Flag(name: .long, help: "Read recovery key from stdin instead of a passphrase.")
    var recoveryKeyStdin = false

    @Flag(name: .long, help: "Update local secrets when names already exist.")
    var overwrite = false

    @Flag(name: .long, help: "Update matching local secrets only when the bundle is newer.")
    var newerOnly = false

    mutating func run() async throws {
        guard !(overwrite && newerOnly) else {
            throw ValidationError("--overwrite and --newer-only cannot be used together")
        }
        try await SyncImporter.importSnapshot(
            from: URL(fileURLWithPath: path).standardizedFileURL,
            credential: SyncDecryptCredential.resolve(
                passphraseEnv: passphraseEnv,
                passphraseStdin: passphraseStdin,
                recoveryKeyEnv: recoveryKeyEnv,
                recoveryKeyStdin: recoveryKeyStdin
            ),
            overwrite: overwrite,
            newerOnly: newerOnly
        )
    }
}

struct SyncPreviewCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "preview",
        abstract: "Decrypt and compare a sync bundle without importing it."
    )

    @Option(name: .long, help: "Bundle path. Defaults to the iCloud sync bundle.")
    var path: String?

    @Option(name: .long, help: "Read passphrase from this environment variable.")
    var passphraseEnv: String?

    @Flag(name: .long, help: "Read passphrase from stdin.")
    var passphraseStdin = false

    @Option(name: .long, help: "Read recovery key from this environment variable instead of a passphrase.")
    var recoveryKeyEnv: String?

    @Flag(name: .long, help: "Read recovery key from stdin instead of a passphrase.")
    var recoveryKeyStdin = false

    mutating func run() async throws {
        let url = syncURL(path: path)
        let snapshot = try SyncDecryptCredential.resolve(
            passphraseEnv: passphraseEnv,
            passphraseStdin: passphraseStdin,
            recoveryKeyEnv: recoveryKeyEnv,
            recoveryKeyStdin: recoveryKeyStdin
        ).decrypt(Data(contentsOf: url))
        let local = try VaultService.live().list()
        let comparison = CloudSyncInspector.compare(snapshot: snapshot, localSecrets: local)
        print("path: \(url.path)")
        print("source: \(snapshot.sourceHost)")
        print("exported: \(ISO8601DateFormatter().string(from: snapshot.exportedAt))")
        print("secrets: \(snapshot.secrets.count)")
        print("saved versions: \(snapshot.revisions.count)")
        print("new: \(comparison.newNames.count)")
        print("backup newer: \(comparison.backupNewerNames.count)")
        print("local newer: \(comparison.localNewerNames.count)")
        print("same timestamp: \(comparison.sameTimestampNames.count)")
    }
}

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
