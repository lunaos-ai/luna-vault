import Foundation
import VaultCore

enum MCPHTTPProcess {
    static func resolveBinary(_ explicit: String?) throws -> String {
        if let explicit {
            guard FileManager.default.isExecutableFile(atPath: explicit) else {
                throw MCPSandboxError.mcpBinaryMissing
            }
            return explicit
        }
        guard let path = MCPBinaryResolver.resolve() else {
            throw MCPSandboxError.mcpBinaryMissing
        }
        return path
    }

    static func spawn(binary: String, port: UInt16) throws -> Process {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: binary)
        process.arguments = ["--http", "--port", "\(port)"]
        var env = ProcessInfo.processInfo.environment
        env["VIBEVAULT_MCP_HTTP"] = "1"
        env["VIBEVAULT_MCP_PORT"] = "\(port)"
        process.environment = env
        process.standardInput = FileHandle.nullDevice
        try process.run()
        return process
    }
}
