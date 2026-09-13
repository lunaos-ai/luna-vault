import Foundation

/// Loopback MCP for sandboxed AI clients. Solo stays local-first: bind 127.0.0.1 only.
public enum MCPSandboxSettings {
    public static let defaultPort: UInt16 = 17_832
    public static let defaultBind = "127.0.0.1"
    public static let defaultTokenMinutes = 30
    public static let minPasskeyLength = 12
    public static let pbkdf2Iterations = 210_000
    public static let maxHTTPBodyBytes = 1_048_576
    public static let maxHTTPHeaderBytes = 65_536

    public static func endpoint(port: UInt16 = defaultPort) -> String {
        "http://\(defaultBind):\(port)/mcp"
    }
}
