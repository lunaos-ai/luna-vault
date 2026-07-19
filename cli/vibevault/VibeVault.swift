import ArgumentParser
import Foundation
import VaultCore

@main
struct VibeVault: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "vibevault",
        abstract: "Local-first secret manager for AI-coding workflows.",
        version: "0.1.0",
        subcommands: [
            AddCommand.self,
            ListCommand.self,
            RevokeCommand.self,
            RotateCommand.self,
            ImportCommand.self,
            ScanCommand.self,
            RunCommand.self,
            PushCommand.self,
            PullCommand.self,
            MCPCommand.self,
            BrowserCommand.self,
            SyncCommand.self,
            SkillCommand.self,
            GuardCommand.self,
            CursorCommand.self,
            LicenseCommand.self
        ]
    )
}
