import ArgumentParser
import Foundation
import VaultCore

@main
struct VibeVault: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "vibevault",
        abstract: "Local-first secret manager for AI-coding workflows.",
        version: "0.2.2",
        subcommands: [
            AddCommand.self,
            DuplicateCommand.self,
            ListCommand.self,
            RevokeCommand.self,
            RotateCommand.self,
            ImportCommand.self,
            ScanCommand.self,
            ProjectsCommand.self,
            RunCommand.self,
            SessionCommand.self,
            PushCommand.self,
            PullCommand.self,
            MCPCommand.self,
            BrowserCommand.self,
            SyncCommand.self,
            RecoveryCommand.self,
            SkillCommand.self,
            GuardCommand.self,
            CursorCommand.self,
            AgentsCommand.self,
            AgentCommand.self,
            LicenseCommand.self,
            OTPCommand.self
        ]
    )
}
