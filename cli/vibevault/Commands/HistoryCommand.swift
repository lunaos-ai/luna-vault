import ArgumentParser
import Foundation
import VaultCore

struct HistoryCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "history",
        abstract: "Show previous values for a secret (masked, newest first)."
    )

    @Argument(help: "Secret name.") var name: String

    mutating func run() async throws {
        let versions = try SecretHistoryStore().versions(name: name)
        guard !versions.isEmpty else {
            print("no history for \(name)")
            return
        }
        for (i, v) in versions.enumerated() {
            let when = v.savedAt.formatted(date: .abbreviated, time: .shortened)
            print("[\(i)] \(v.maskedValue)  \(when)")
        }
    }
}
