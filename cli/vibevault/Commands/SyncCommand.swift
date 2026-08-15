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
            SyncImportCommand.self,
            SyncPreviewCommand.self,
            SyncBackupCommand.self,
            SyncHistoryCommand.self,
            SyncRecoveryKeyCommand.self
        ]
    )
}
