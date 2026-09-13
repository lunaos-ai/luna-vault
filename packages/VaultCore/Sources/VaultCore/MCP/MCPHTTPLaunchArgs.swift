import Foundation

/// Parses `vibevault-mcp --http` / `VIBEVAULT_MCP_HTTP` launch flags.
public enum MCPHTTPLaunchArgs {
    public static func portIfHTTP(
        arguments: [String],
        environment: [String: String]
    ) -> UInt16? {
        let httpFlag = arguments.contains("--http") || environment["VIBEVAULT_MCP_HTTP"] == "1"
        guard httpFlag else { return nil }
        if let idx = arguments.firstIndex(of: "--port"),
           arguments.index(after: idx) < arguments.endIndex,
           let port = UInt16(arguments[arguments.index(after: idx)]),
           port > 0 {
            return port
        }
        if let raw = environment["VIBEVAULT_MCP_PORT"], let port = UInt16(raw), port > 0 {
            return port
        }
        return MCPSandboxSettings.defaultPort
    }
}
