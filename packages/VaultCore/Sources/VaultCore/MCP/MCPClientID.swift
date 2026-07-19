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
        case .vscode: return "~/Library/Application Support/Code/User/mcp.json"
        case .devin: return "~/.devin/mcp.json (or Devin workspace MCP settings)"
        case .claudeCode: return "~/.claude/mcp.json"
        case .claudeDesktop: return "~/Library/Application Support/Claude/claude_desktop_config.json"
        }
    }

    public var configURL: URL {
        let home = FileManager.default.homeDirectoryForCurrentUser
        switch self {
        case .cursor: return home.appendingPathComponent(".cursor/mcp.json")
        case .vscode:
            return home.appendingPathComponent("Library/Application Support/Code/User/mcp.json")
        case .devin: return home.appendingPathComponent(".devin/mcp.json")
        case .claudeCode: return home.appendingPathComponent(".claude/mcp.json")
        case .claudeDesktop:
            return home.appendingPathComponent("Library/Application Support/Claude/claude_desktop_config.json")
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
