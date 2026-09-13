import ArgumentParser
import Foundation
import VaultCore

struct MCPSandboxCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "sandbox",
        abstract: "Mint a passkey-gated loopback MCP session for an AI sandbox.",
        subcommands: [MCPSandboxStartCommand.self]
    )
}

struct MCPSandboxStartCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "start",
        abstract: "Verify the user passkey, mint a bearer token, install HTTP MCP config, listen."
    )

    @Option(name: .long, help: "Client id: cursor, vscode, devin, claude-code, claude-desktop.")
    var client: String = "cursor"

    @Option(name: .long, help: "Loopback port.")
    var port: Int = Int(MCPSandboxSettings.defaultPort)

    @Option(name: .long, help: "Token lifetime in minutes (5-480).")
    var minutes: Int = MCPSandboxSettings.defaultTokenMinutes

    @Option(name: .long, help: "Read the passkey from this environment variable.")
    var passkeyEnv: String?

    @Option(name: .long, help: "Path to vibevault-mcp.")
    var binary: String?

    @Flag(name: .long, help: "Skip writing HTTP MCP config; only listen.")
    var noInstall = false

    mutating func run() async throws {
        guard let port = UInt16(exactly: port), port > 0 else {
            throw ValidationError("invalid port")
        }
        guard let clientID = MCPClientID(rawValue: client) else {
            throw ValidationError("unknown client: \(client)")
        }
        let prefs = KeychainPrefs()
        let store = MCPSandboxPasskeyStore(prefs: prefs)
        guard store.isEnrolled else { throw MCPSandboxError.passkeyNotEnrolled }
        let passkey = try MCPPasskeyInput.resolve(envName: passkeyEnv, confirm: false)
        guard try store.verify(passkey) else { throw MCPSandboxError.unauthorized }
        let token = try MCPSandboxTokenMint.mint(minutes: minutes, prefs: prefs)
        let endpoint = MCPSandboxSettings.endpoint(port: port)
        if !noInstall {
            try MCPClientInstaller.installHTTP(client: clientID, url: endpoint, bearerToken: token.value)
            print("installed HTTP MCP for \(clientID.displayName) → \(clientID.configHint)")
        }
        print("sandbox MCP \(endpoint) (token \(minutes) min)")
        print("allowlisted secrets only; agents cannot enable MCP")
        let path = try MCPHTTPProcess.resolveBinary(binary)
        let process = try MCPHTTPProcess.spawn(binary: path, port: port)
        process.waitUntilExit()
        if process.terminationStatus != 0 {
            throw ExitCode(process.terminationStatus)
        }
    }
}
