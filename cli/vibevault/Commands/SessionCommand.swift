import ArgumentParser
import Foundation
import VaultCore

struct SessionCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "session",
        abstract: "Manage the shared, time-bounded VibeVault unlock session.",
        subcommands: [SessionStatusCommand.self, SessionUnlockCommand.self, SessionLockCommand.self]
    )
}

struct SessionStatusCommand: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "status")

    mutating func run() throws {
        guard let status = SharedUnlockSession.status() else {
            print("locked")
            return
        }
        let remaining = Int(ceil(status.remainingSeconds() / 60))
        print("unlocked for \(remaining) more minute(s), until \(status.expiresAt.formatted(date: .omitted, time: .standard))")
    }
}

struct SessionUnlockCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(commandName: "unlock")

    @Option(name: .long, help: "Unlock duration in minutes (5-480).")
    var minutes: Int = 15

    mutating func run() async throws {
        guard (5...480).contains(minutes) else {
            throw ValidationError("--minutes must be between 5 and 480")
        }
        let gate = BiometricGate(sharedSessionURL: nil)
        try await gate.authenticate(reason: "Unlock all VibeVault clients for \(minutes) minutes")
        let status = try SharedUnlockSession.unlock(for: TimeInterval(minutes * 60))
        print("unlocked until \(status.expiresAt.formatted(date: .omitted, time: .standard))")
    }
}

struct SessionLockCommand: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "lock")

    mutating func run() throws {
        SharedUnlockSession.lock()
        print("locked")
    }
}
