import ArgumentParser
import Darwin
import Foundation
import VaultCore

struct RecoveryCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "recovery",
        abstract: "Inspect or restore local vault recovery protection.",
        subcommands: [RecoveryStatusCommand.self, RecoveryRestoreCommand.self]
    )
}

struct RecoveryStatusCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "status",
        abstract: "Show whether the local encrypted vault has recovery protection."
    )

    mutating func run() {
        let directory = EncryptedVaultStore.defaultDirectory()
        let vaultExists = FileManager.default.fileExists(
            atPath: directory.appendingPathComponent("secrets.vault").path
        )
        print("encrypted vault: \(vaultExists ? "present" : "not created")")
        print("local recovery: \(LocalVaultRecovery.isProtected(directory: directory) ? "protected" : "not protected")")
        print("Time Machine path: \(directory.path)")
    }
}

struct RecoveryRestoreCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "restore",
        abstract: "Restore a missing Keychain master key from local recovery protection."
    )

    @Flag(name: .long, help: "Read the recovery key from standard input.")
    var recoveryKeyStdin = false

    @Option(name: .long, help: "Read the recovery key from this environment variable.")
    var recoveryKeyEnv: String?

    mutating func run() throws {
        let recoveryKey = try resolveRecoveryKey()
        try LocalVaultRecovery.restore(
            directory: EncryptedVaultStore.defaultDirectory(),
            recoveryKey: recoveryKey
        )
        print("restored the vault master key to macOS Keychain")
    }

    private func resolveRecoveryKey() throws -> String {
        guard !(recoveryKeyStdin && recoveryKeyEnv != nil) else {
            throw ValidationError("choose either --recovery-key-stdin or --recovery-key-env")
        }
        if let recoveryKeyEnv {
            guard let value = ProcessInfo.processInfo.environment[recoveryKeyEnv], !value.isEmpty else {
                throw ValidationError("recovery-key environment variable is empty")
            }
            return try CloudRecoveryKey.canonicalize(value)
        }
        if recoveryKeyStdin {
            guard let value = readLine(), !value.isEmpty else {
                throw ValidationError("no recovery key provided on stdin")
            }
            return try CloudRecoveryKey.canonicalize(value)
        }
        guard isatty(STDIN_FILENO) == 1 else {
            throw ValidationError("use --recovery-key-stdin or --recovery-key-env")
        }
        return try CloudRecoveryKey.canonicalize(
            SyncPassphrase.readHiddenLine(prompt: "Recovery key: ")
        )
    }
}
