import Foundation

/// One-click: Cursor rules + skill + MCP + guard + ignore files + AGENTS.md.
public enum CursorProjectPrep {
    public struct Result: Equatable, Sendable {
        public let rulesInstalled: Bool
        public let skillInstalled: Bool
        public let mcpInstalled: Bool
        public let guardInstalled: Bool
        public let messages: [String]

        public init(
            rulesInstalled: Bool,
            skillInstalled: Bool,
            mcpInstalled: Bool,
            guardInstalled: Bool,
            messages: [String]
        ) {
            self.rulesInstalled = rulesInstalled
            self.skillInstalled = skillInstalled
            self.mcpInstalled = mcpInstalled
            self.guardInstalled = guardInstalled
            self.messages = messages
        }
    }

    public static func prepare(
        projectURL: URL,
        mcpBinaryPath: String?,
        installGuard: Bool = true,
        writeIgnores: Bool = true,
        writeAgentsMd: Bool = true,
        knownSecrets: Set<String> = []
    ) throws -> Result {
        var messages: [String] = []
        try CursorRulesInstaller.install(projectURL: projectURL)
        messages.append("Cursor rules")

        try AgentSkillInstaller.install(target: .cursor)
        messages.append("Skill")

        var mcpOK = false
        if let binary = mcpBinaryPath, FileManager.default.isExecutableFile(atPath: binary) {
            try MCPClientInstaller.install(client: .cursor, binaryPath: binary)
            mcpOK = true
            messages.append("MCP")
        } else {
            messages.append("MCP skipped")
        }

        var guardOK = false
        if installGuard {
            let hooks = projectURL.appendingPathComponent(".git/hooks")
            if FileManager.default.fileExists(atPath: hooks.path) {
                try PreCommitGuard.install(projectURL: projectURL)
                guardOK = true
                messages.append("Pre-commit guard")
            } else {
                messages.append("Guard skipped")
            }
        }

        if writeIgnores {
            if try ProjectIgnoreAssistant.ensureGitignore(projectURL: projectURL) {
                messages.append(".gitignore")
            }
            if try ProjectIgnoreAssistant.ensureCursorignore(projectURL: projectURL) {
                messages.append(".cursorignore")
            }
        }

        var scan: ScanResult?
        if writeAgentsMd {
            scan = try? ProjectScanner().scan(projectURL: projectURL, knownSecrets: knownSecrets)
            _ = try AgentsMarkdownGenerator.install(projectURL: projectURL, scan: scan)
            messages.append("AGENTS.md")
        }

        return Result(
            rulesInstalled: true,
            skillInstalled: true,
            mcpInstalled: mcpOK,
            guardInstalled: guardOK,
            messages: messages
        )
    }
}
