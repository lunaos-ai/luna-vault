import ArgumentParser
import Foundation
import VaultCore

@main
struct LunaVault: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "lunavault",
        abstract: "Local-first secret manager for AI-coding workflows.",
        version: "0.1.0-dev",
        subcommands: [
            AddCommand.self,
            ListCommand.self,
            RevokeCommand.self,
            ScanCommand.self,
            RunCommand.self,
            PushCommand.self,
            PullCommand.self
        ]
    )
}
