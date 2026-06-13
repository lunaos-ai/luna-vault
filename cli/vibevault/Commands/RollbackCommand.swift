import ArgumentParser
import Foundation
import VaultCore

struct RollbackCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "rollback",
        abstract: "Restore a previous value from history (saves current first)."
    )

    @Argument(help: "Secret name.") var name: String

    @Option(name: .shortAndLong, help: "History index to restore (0 = most recent).") var index: Int = 0

    mutating func run() async throws {
        let service = try VaultService.live()
        let store = SecretHistoryStore()
        let versions = try store.versions(name: name)
        guard versions.indices.contains(index) else {
            FileHandle.standardError.write(Data("no history entry at index \(index)\n".utf8))
            throw ExitCode(2)
        }
        let target = versions[index]
        do {
            let current = try await service.read(name: name, reason: "Roll back \(name)")
            try store.record(name: name, value: current.value)
            try await service.rotate(name: name, newValue: target.value)
            try? service.recordEvent(
                name: name, action: .rollback, projectPath: service.currentProjectPath())
            let when = target.savedAt.formatted(date: .abbreviated, time: .shortened)
            print("rolled back \(name) to version [\(index)] from \(when)")
        } catch SecretError.notFound {
            FileHandle.standardError.write(Data("secret '\(name)' not found\n".utf8))
            throw ExitCode(2)
        }
    }
}
