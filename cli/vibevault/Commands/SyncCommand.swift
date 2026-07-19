import ArgumentParser
import Darwin
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

private func syncURL(path: String?) -> URL {
    if let path, !path.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
        return URL(fileURLWithPath: path).standardizedFileURL
    }
    return CloudSync.defaultICloudURL()
}

private enum SyncSnapshotBuilder {
    static func snapshot() async throws -> CloudSyncSnapshot {
        let service = try VaultService.live()
        let names = try service.list().map(\.name).sorted()
        var secrets: [CloudSyncSecret] = []
        for name in names {
            let secret = try await service.read(name: name, reason: "Export \(name) for encrypted cloud sync")
            secrets.append(CloudSyncSecret(secret: secret))
        }
        return CloudSyncSnapshot(secrets: secrets)
    }
}

private enum SyncImporter {
    static func importSnapshot(from url: URL, passphrase: String, overwrite: Bool) async throws {
        let data = try Data(contentsOf: url)
        let snapshot = try CloudSync.decrypt(data, passphrase: passphrase)
        let service = try VaultService.live()
        var imported: [String] = []
        var updated: [String] = []
        var skipped: [String] = []
        var failed: [(String, String)] = []

        for item in snapshot.secrets {
            do {
                if try service.store.exists(name: item.name) {
                    guard overwrite else {
                        skipped.append(item.name)
                        continue
                    }
                    try service.update(
                        name: item.name,
                        value: item.value,
                        notes: item.notes,
                        expiresAt: item.expiresAt,
                        rotateEveryDays: item.rotateEveryDays,
                        mcpAllowed: item.mcpAllowed,
                        createdAt: item.createdAt
                    )
                    updated.append(item.name)
                } else {
                    try service.add(
                        name: item.name,
                        value: item.value,
                        notes: item.notes,
                        expiresAt: item.expiresAt,
                        rotateEveryDays: item.rotateEveryDays,
                        mcpAllowed: item.mcpAllowed,
                        createdAt: item.createdAt
                    )
                    imported.append(item.name)
                }
                try service.recordEvent(name: item.name, action: .importEvent, projectPath: service.currentProjectPath())
            } catch {
                failed.append((item.name, "\(error)"))
            }
        }

        print("imported \(imported.count), updated \(updated.count), skipped \(skipped.count), failed \(failed.count)")
        print("source: \(snapshot.sourceHost) at \(ISO8601DateFormatter().string(from: snapshot.exportedAt))")
        for failure in failed {
            FileHandle.standardError.write(Data("failed \(failure.0): \(failure.1)\n".utf8))
        }
        if !failed.isEmpty { throw ExitCode(4) }
    }
}

private enum SyncPassphrase {
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

    private static func readHiddenLine(prompt: String) throws -> String {
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
