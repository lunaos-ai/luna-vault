import ArgumentParser
import Foundation
import VaultCore

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

