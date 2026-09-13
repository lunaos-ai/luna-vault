import ArgumentParser
import Foundation
import VaultCore

enum MCPPasskeyInput {
    static func resolve(envName: String?, confirm: Bool) throws -> String {
        if let envName {
            guard let value = ProcessInfo.processInfo.environment[envName], !value.isEmpty else {
                throw ValidationError("passkey environment variable is empty")
            }
            return value
        }
        let first = try SyncPassphrase.readHiddenLine(prompt: "Sandbox passkey: ")
        guard confirm else { return first }
        let second = try SyncPassphrase.readHiddenLine(prompt: "Confirm sandbox passkey: ")
        guard first == second else { throw ValidationError("passkeys did not match") }
        return first
    }
}

struct MCPPasskeyCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "passkey",
        abstract: "Enroll the sandbox MCP passkey (PBKDF2 hash in the local vault prefs).",
        subcommands: [MCPPasskeySetCommand.self, MCPPasskeyStatusCommand.self, MCPPasskeyClearCommand.self]
    )
}

struct MCPPasskeySetCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "set",
        abstract: "Enroll or rotate the sandbox MCP passkey."
    )

    @Option(name: .long, help: "Read the passkey from this environment variable.")
    var passkeyEnv: String?

    mutating func run() async throws {
        let passkey = try MCPPasskeyInput.resolve(envName: passkeyEnv, confirm: passkeyEnv == nil)
        try MCPSandboxPasskeyStore(prefs: KeychainPrefs()).enroll(passkey)
        print("sandbox passkey enrolled (tokens from the previous passkey are revoked)")
    }
}

struct MCPPasskeyStatusCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "status",
        abstract: "Show whether a sandbox MCP passkey is enrolled."
    )

    mutating func run() async throws {
        let enrolled = MCPSandboxPasskeyStore(prefs: KeychainPrefs()).isEnrolled
        print(enrolled ? "enrolled" : "missing")
    }
}

struct MCPPasskeyClearCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "clear",
        abstract: "Remove the sandbox MCP passkey and revoke minted tokens."
    )

    mutating func run() async throws {
        MCPSandboxPasskeyStore(prefs: KeychainPrefs()).clear()
        print("sandbox passkey cleared")
    }
}
