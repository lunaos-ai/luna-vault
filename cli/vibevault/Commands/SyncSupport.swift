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
        return CloudSyncSnapshot(secrets: secrets)
    }
}

enum SyncImporter {
    static func importSnapshot(from url: URL, passphrase: String, overwrite: Bool) async throws {
        let snapshot = try CloudSync.decrypt(Data(contentsOf: url), passphrase: passphrase)
        let service = try VaultService.live()
        var result = SyncImportResult()

        for item in snapshot.secrets {
            do {
                try upsert(item, into: service, overwrite: overwrite, result: &result)
                try service.recordEvent(name: item.name, action: .importEvent, projectPath: service.currentProjectPath())
            } catch {
                result.failed.append((item.name, "\(error)"))
            }
        }

        print("imported \(result.imported.count), updated \(result.updated.count), skipped \(result.skipped.count), failed \(result.failed.count)")
        print("source: \(snapshot.sourceHost) at \(ISO8601DateFormatter().string(from: snapshot.exportedAt))")
        for failure in result.failed {
            FileHandle.standardError.write(Data("failed \(failure.0): \(failure.1)\n".utf8))
        }
        if !result.failed.isEmpty { throw ExitCode(4) }
    }

    private static func upsert(
        _ item: CloudSyncSecret,
        into service: VaultService,
        overwrite: Bool,
        result: inout SyncImportResult
    ) throws {
        if try service.store.exists(name: item.name) {
            guard overwrite else {
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
            mcpAllowed: item.mcpAllowed, createdAt: item.createdAt
        )
    }

    private static func add(_ item: CloudSyncSecret, to service: VaultService) throws {
        try service.add(
            name: item.name, value: item.value, notes: item.notes,
            expiresAt: item.expiresAt, rotateEveryDays: item.rotateEveryDays,
            mcpAllowed: item.mcpAllowed, createdAt: item.createdAt
        )
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
