import Foundation

/// When a coding agent is the caller, only `mcpAllowed` secrets may be read.
public enum MCPAllowlist {
    public static let codingAgentNames: Set<String> = [
        "claude-code", "cursor", "vscode", "devin", "sourcegraph-cody", "aider"
    ]

    /// Process basenames that mean an AI agent, not a human IDE or shell.
    public static let codingAgentBinaries: Set<String> = [
        "cursor-agent", "claude", "claude-code", "copilot", "aider", "devin", "cody"
    ]

    public static let agentEnvKeys: [String: String] = [
        "CLAUDECODE": "claude-code",
        "CLAUDE_CODE": "claude-code",
        "CURSOR_AGENT": "cursor",
        "GEMINI_CLI": "gemini-cli",
        "AIDER": "aider"
    ]

    public static func processKey(_ path: String) -> String {
        let base = URL(fileURLWithPath: path).lastPathComponent.lowercased()
        return base.hasSuffix(".exe") ? String(base.dropLast(4)) : base
    }

    public static func agent(fromEnv env: [String: String]) -> DetectedAgent? {
        for (key, name) in agentEnvKeys {
            if let value = env[key], !value.isEmpty {
                return DetectedAgent(name: name, confidence: .high, source: "env:\(key)")
            }
        }
        return nil
    }

    public static func blockedNames(
        _ names: [String],
        secrets: [Secret],
        agent: DetectedAgent
    ) -> [String] {
        guard agent.requiresMCPAllowlist else { return [] }
        let allowed = Set(secrets.filter(\.mcpAllowed).map(\.name))
        return names.filter { !allowed.contains($0) }
    }
}

extension DetectedAgent {
    public var requiresMCPAllowlist: Bool {
        if source == "LUNA_AGENT" || source == "mcp-initialize" { return true }
        if source.hasPrefix("env:") { return true }
        if let binary = Self.binary(from: source) {
            return MCPAllowlist.codingAgentBinaries.contains(binary)
        }
        return false
    }

    private static func binary(from source: String) -> String? {
        let prefixes = ["parent-process:", "ancestor:"]
        for prefix in prefixes where source.hasPrefix(prefix) {
            return String(source.dropFirst(prefix.count))
        }
        return nil
    }
}
