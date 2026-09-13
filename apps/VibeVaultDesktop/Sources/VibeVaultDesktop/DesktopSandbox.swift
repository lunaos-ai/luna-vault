import Foundation
import VaultCore

enum DesktopSandbox {
    static let shared = ProcessHolder()

    static func enroll(passkey: String, confirm: String) throws {
        guard passkey == confirm else { throw MCPSandboxError.passkeyMismatch }
        try MCPSandboxPasskeyStore(prefs: DesktopVault.prefs()).enroll(passkey)
    }

    static func isEnrolled() -> Bool {
        MCPSandboxPasskeyStore(prefs: DesktopVault.prefs()).isEnrolled
    }

    static func isRunning() -> Bool {
        shared.process?.isRunning == true
    }

    static func start(passkey: String, minutes: Int) throws -> MCPSandboxToken {
        let prefs = DesktopVault.prefs()
        let store = MCPSandboxPasskeyStore(prefs: prefs)
        guard store.isEnrolled else { throw MCPSandboxError.passkeyNotEnrolled }
        guard try store.verify(passkey) else { throw MCPSandboxError.unauthorized }
        if isRunning() { throw SecretError.vaultIO("sandbox MCP is already running") }
        let token = try MCPSandboxTokenMint.mint(minutes: minutes, prefs: prefs)
        let endpoint = MCPSandboxSettings.endpoint()
        try MCPClientInstaller.installHTTP(client: .cursor, url: endpoint, bearerToken: token.value)
        let binary = try MCPHTTPLaunch.resolveBinary()
        let process = Process()
        process.executableURL = URL(fileURLWithPath: binary)
        process.arguments = ["--http", "--port", "\(MCPSandboxSettings.defaultPort)"]
        var env = ProcessInfo.processInfo.environment
        env["VIBEVAULT_MCP_HTTP"] = "1"
        env["VIBEVAULT_MCP_PORT"] = "\(MCPSandboxSettings.defaultPort)"
        process.environment = env
        process.standardInput = FileHandle.nullDevice
        try process.run()
        shared.process = process
        return token
    }

    static func stop() {
        shared.process?.terminate()
        shared.process = nil
    }
}

enum MCPHTTPLaunch {
    static func resolveBinary() throws -> String {
        guard let path = MCPBinaryResolver.resolve() else {
            throw MCPSandboxError.mcpBinaryMissing
        }
        return path
    }
}

final class ProcessHolder: @unchecked Sendable {
    var process: Process?
}
