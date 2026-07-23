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
            SyncImportCommand.self
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
        print("icloud path: \(cloudURL.path)")
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

    mutating func run() async throws {
        guard to == "icloud" else { throw ValidationError("unsupported sync destination: \(to)") }
        let url = syncURL(path: path)
        let passphrase = try SyncPassphrase.resolve(envName: passphraseEnv, stdin: passphraseStdin, confirm: true)
        let snapshot = try await SyncSnapshotBuilder.snapshot()
        let data = try CloudSync.encrypt(snapshot, passphrase: passphrase)
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

    @Flag(name: .long, help: "Update local secrets when names already exist.")
    var overwrite = false

    mutating func run() async throws {
        guard from == "icloud" else { throw ValidationError("unsupported sync source: \(from)") }
        let url = syncURL(path: path)
        try await SyncImporter.importSnapshot(
            from: url,
            passphrase: SyncPassphrase.resolve(envName: passphraseEnv, stdin: passphraseStdin),
            overwrite: overwrite
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

    mutating func run() async throws {
        let passphrase = try SyncPassphrase.resolve(envName: passphraseEnv, stdin: passphraseStdin, confirm: true)
        let snapshot = try await SyncSnapshotBuilder.snapshot()
        let data = try CloudSync.encrypt(snapshot, passphrase: passphrase)
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

    @Flag(name: .long, help: "Update local secrets when names already exist.")
    var overwrite = false

    mutating func run() async throws {
        try await SyncImporter.importSnapshot(
            from: URL(fileURLWithPath: path).standardizedFileURL,
            passphrase: SyncPassphrase.resolve(envName: passphraseEnv, stdin: passphraseStdin),
            overwrite: overwrite
        )
    }
}
