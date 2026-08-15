import ArgumentParser
import Foundation
import VaultCore

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

