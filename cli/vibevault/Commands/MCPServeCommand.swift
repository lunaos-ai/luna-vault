import ArgumentParser
import Foundation
import VaultCore

struct MCPServeCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "serve",
        abstract: "Start loopback HTTP MCP (passkey-gated) for sandboxed AI clients."
    )

    @Flag(name: .long, help: "Listen on 127.0.0.1 instead of stdio.")
    var http = false

    @Option(name: .long, help: "Loopback port.")
    var port: Int = Int(MCPSandboxSettings.defaultPort)

    @Option(name: .long, help: "Session token lifetime in minutes.")
    var minutes: Int = MCPSandboxSettings.defaultTokenMinutes

    @Option(name: .long, help: "Read the passkey from this environment variable.")
    var passkeyEnv: String?

    @Option(name: .long, help: "Path to vibevault-mcp.")
    var binary: String?

    mutating func run() async throws {
        guard http else {
            throw ValidationError("pass --http to serve loopback MCP for AI sandboxes")
        }
        guard let port = UInt16(exactly: port), port > 0 else {
            throw ValidationError("invalid port")
        }
        let prefs = KeychainPrefs()
        let store = MCPSandboxPasskeyStore(prefs: prefs)
        guard store.isEnrolled else { throw MCPSandboxError.passkeyNotEnrolled }
        let passkey = try MCPPasskeyInput.resolve(envName: passkeyEnv, confirm: false)
        guard try store.verify(passkey) else { throw MCPSandboxError.unauthorized }
        let token = try MCPSandboxTokenMint.mint(minutes: minutes, prefs: prefs)
        let path = try MCPHTTPProcess.resolveBinary(binary)
        FileHandle.standardError.write(Data("token expires \(token.expiresAt)\n".utf8))
        FileHandle.standardError.write(Data("Authorization: Bearer \(token.value)\n".utf8))
        print(MCPSandboxSettings.endpoint(port: port))
        let process = try MCPHTTPProcess.spawn(binary: path, port: port)
        process.waitUntilExit()
        if process.terminationStatus != 0 {
            throw ExitCode(process.terminationStatus)
        }
    }
}
