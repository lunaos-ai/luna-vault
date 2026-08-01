import ArgumentParser
import Foundation
import VaultCore

@main
struct VibeVault: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "vibevault",
        abstract: "Local-first secret manager for AI-coding workflows.",
        discussion: """
        Secrets remain local. Commands that read the vault must run on the same
        Mac and user with access to the macOS Keychain security context.

        AI-agent sandboxes may need approved host-level execution even when the
        same command works in Terminal. Use the narrowest scope:

          vibevault run --only NAME -- command

        If Terminal works but an agent reports "bad master key in Keychain",
        never reset the vault master key. Retry with approved local execution.
        See `vibevault help run` for safe use and controlled retrieval.
        """,
        version: "0.1.2",
        subcommands: [
            AddCommand.self,
            ListCommand.self,
            RevokeCommand.self,
            RotateCommand.self,
            ImportCommand.self,
            ScanCommand.self,
            RunCommand.self,
            SessionCommand.self,
            PushCommand.self,
            PullCommand.self,
            MCPCommand.self,
            BrowserCommand.self,
            SyncCommand.self,
            SkillCommand.self,
            GuardCommand.self,
            CursorCommand.self,
            AgentsCommand.self,
            LicenseCommand.self
        ]
    )
}
