import Foundation

public enum MCPClientMapper {
    public static func canonical(from raw: String) -> String {
        var key = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if key.hasPrefix("mcp:") { key = String(key.dropFirst(4)) }
        if key.contains("cursor") { return "cursor" }
        if key.contains("devin") { return "devin" }
        if key.contains("copilot") || key.contains("vscode") || key == "code"
            || key.contains("vs code") || key.contains("vs-code") { return "vscode" }
        if key.contains("claude") {
            return key.contains("code") || key.contains("cli") ? "claude-code" : "claude-desktop"
        }
        if let mapped = AgentDetector.knownAgents[key] { return mapped }
        return key.replacingOccurrences(of: " ", with: "-")
    }
}
