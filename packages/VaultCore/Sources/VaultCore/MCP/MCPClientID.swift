import Foundation

public enum MCPClientID: String, CaseIterable, Sendable {
    case cursor
    case vscode
    case devin
    case claudeCode = "claude-code"
    case claudeDesktop = "claude-desktop"

    public var displayName: String {
        switch self {
        case .cursor: return "Cursor"
        case .vscode: return "VS Code"
        case .devin: return "Devin"
        case .claudeCode: return "Claude Code"
        case .claudeDesktop: return "Claude Desktop"
        }
    }

    public var lunaAgent: String { rawValue }

    public var configHint: String {
        switch self {
        case .cursor: return "~/.cursor/mcp.json"
        case .vscode:
            #if os(macOS)
            return "~/Library/Application Support/Code/User/mcp.json"
            #elseif os(Windows)
            return "%APPDATA%/Code/User/mcp.json"
            #else
            return "~/.config/Code/User/mcp.json"
            #endif
        case .devin: return "~/.devin/mcp.json (or Devin workspace MCP settings)"
        case .claudeCode: return "~/.claude/mcp.json"
        case .claudeDesktop:
            #if os(macOS)
            return "~/Library/Application Support/Claude/claude_desktop_config.json"
            #elseif os(Windows)
            return "%APPDATA%/Claude/claude_desktop_config.json"
            #else
            return "~/.config/Claude/claude_desktop_config.json"
            #endif
        }
    }

    public var configURL: URL {
        let home = FileManager.default.homeDirectoryForCurrentUser
        switch self {
        case .cursor: return home.appendingPathComponent(".cursor/mcp.json")
        case .vscode:
            #if os(macOS)
            return home.appendingPathComponent("Library/Application Support/Code/User/mcp.json")
            #elseif os(Windows)
            let appData = ProcessInfo.processInfo.environment["APPDATA"] ?? home.appendingPathComponent("AppData/Roaming").path
            return URL(fileURLWithPath: appData).appendingPathComponent("Code/User/mcp.json")
            #else
            return home.appendingPathComponent(".config/Code/User/mcp.json")
            #endif
        case .devin: return home.appendingPathComponent(".devin/mcp.json")
        case .claudeCode: return home.appendingPathComponent(".claude/mcp.json")
        case .claudeDesktop:
            #if os(macOS)
            return home.appendingPathComponent("Library/Application Support/Claude/claude_desktop_config.json")
            #elseif os(Windows)
            let appData = ProcessInfo.processInfo.environment["APPDATA"] ?? home.appendingPathComponent("AppData/Roaming").path
            return URL(fileURLWithPath: appData).appendingPathComponent("Claude/claude_desktop_config.json")
            #else
            return home.appendingPathComponent(".config/Claude/claude_desktop_config.json")
            #endif
        }
    }
}

public struct MCPInstallStatus: Equatable, Sendable {
    public let client: MCPClientID
    public let configExists: Bool
    public let installed: Bool
    public let parentDirExists: Bool

    public init(client: MCPClientID, configExists: Bool, installed: Bool, parentDirExists: Bool) {
        self.client = client
        self.configExists = configExists
        self.installed = installed
        self.parentDirExists = parentDirExists
    }
}
