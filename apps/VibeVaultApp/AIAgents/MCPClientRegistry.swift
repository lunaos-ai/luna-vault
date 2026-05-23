import Foundation

enum MCPClientKind: String, CaseIterable, Identifiable {
    case claudeCode = "claude-code"
    case cursor
    case claudeDesktop = "claude-desktop"
    case windsurf

    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .claudeCode: return "Claude Code"
        case .cursor: return "Cursor"
        case .claudeDesktop: return "Claude Desktop"
        case .windsurf: return "Windsurf"
        }
    }
    var systemImage: String { "sparkles" }
    var docsHint: String {
        switch self {
        case .claudeCode: return "Adds to ~/.claude/mcp.json"
        case .cursor: return "Adds to ~/.cursor/mcp.json"
        case .claudeDesktop: return "Adds to ~/Library/Application Support/Claude/claude_desktop_config.json"
        case .windsurf: return "Adds to ~/.codeium/windsurf/mcp_config.json"
        }
    }

    var configURL: URL {
        let home = FileManager.default.homeDirectoryForCurrentUser
        switch self {
        case .claudeCode: return home.appendingPathComponent(".claude/mcp.json")
        case .cursor: return home.appendingPathComponent(".cursor/mcp.json")
        case .claudeDesktop: return home.appendingPathComponent("Library/Application Support/Claude/claude_desktop_config.json")
        case .windsurf: return home.appendingPathComponent(".codeium/windsurf/mcp_config.json")
        }
    }
}

struct MCPClientStatus: Equatable {
    let kind: MCPClientKind
    let configExists: Bool
    let installed: Bool
    let parentDirExists: Bool
}
