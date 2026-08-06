import Foundation

public enum AgentSkillTarget: String, CaseIterable, Sendable {
    case cursor
    case claude
    case devin

    public var displayName: String {
        switch self {
        case .cursor: return "Cursor"
        case .claude: return "Claude Code"
        case .devin: return "Devin"
        }
    }

    /// Root directory that holds all skill folders for this agent.
    public var skillsRootDirectory: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".\(rawValue)/skills")
    }

    /// Backward-compatible path for the primary Vibe Vault skill.
    public var installDirectory: URL {
        installDirectory(for: .vibevault)
    }

    public func installDirectory(for skillName: AgentSkillName) -> URL {
        skillsRootDirectory.appendingPathComponent(skillName.rawValue)
    }
}

public enum AgentSkillName: String, CaseIterable, Sendable {
    case vibevault
    case lunaVaultAgentCoordination = "luna-vault-agent-coordination"

    public var displayName: String {
        switch self {
        case .vibevault: return "Vibe Vault"
        case .lunaVaultAgentCoordination: return "Luna Vault Agent Coordination"
        }
    }

    public var bundledContent: String {
        switch self {
        case .vibevault: return AgentSkillContent.markdown
        case .lunaVaultAgentCoordination: return CoordinationSkillContent.markdown
        }
    }

    public func repoPath(relativeTo root: URL) -> URL {
        switch self {
        case .vibevault:
            return root.appendingPathComponent("skills/vibevault/SKILL.md")
        case .lunaVaultAgentCoordination:
            return root.appendingPathComponent(".devin/skills/luna-vault-agent-coordination/SKILL.md")
        }
    }
}

public struct AgentSkillStatus: Equatable, Sendable {
    public let target: AgentSkillTarget
    public let skillName: AgentSkillName
    public let installed: Bool
    public let path: URL

    public init(target: AgentSkillTarget, skillName: AgentSkillName, installed: Bool, path: URL) {
        self.target = target
        self.skillName = skillName
        self.installed = installed
        self.path = path
    }
}

public enum AgentSkillInstaller {
    public static let skillFileName = "SKILL.md"

    public static func bundledSkillContent() -> String {
        AgentSkillContent.markdown
    }

    public static func status(
        of target: AgentSkillTarget,
        skillName: AgentSkillName = .vibevault
    ) -> AgentSkillStatus {
        let dir = target.installDirectory(for: skillName)
        let file = dir.appendingPathComponent(skillFileName)
        return AgentSkillStatus(
            target: target,
            skillName: skillName,
            installed: FileManager.default.fileExists(atPath: file.path),
            path: file
        )
    }

    public static func install(
        target: AgentSkillTarget,
        skillName: AgentSkillName = .vibevault,
        content: String? = nil
    ) throws {
        let dir = target.installDirectory(for: skillName)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let body = content ?? skillName.bundledContent
        try body.write(to: dir.appendingPathComponent(skillFileName), atomically: true, encoding: .utf8)
    }

    /// Install every skill for every target, optionally loading from a repo.
    public static func installAll(fromRepo root: URL? = nil) throws {
        for target in AgentSkillTarget.allCases {
            try installAll(target: target, fromRepo: root)
        }
    }

    /// Install all known skills for a single target.
    public static func installAll(target: AgentSkillTarget, fromRepo root: URL? = nil) throws {
        for skillName in AgentSkillName.allCases {
            let content = root.map { loadSkillFromRepo(root: $0, skillName: skillName) } ?? nil
            try install(target: target, skillName: skillName, content: content ?? nil)
        }
    }

    public static func uninstall(target: AgentSkillTarget) throws {
        let dir = target.skillsRootDirectory
        if FileManager.default.fileExists(atPath: dir.path) {
            try FileManager.default.removeItem(at: dir)
        }
    }

    public static func isOutdated(
        target: AgentSkillTarget,
        skillName: AgentSkillName = .vibevault
    ) -> Bool {
        let status = status(of: target, skillName: skillName)
        guard status.installed,
              let body = try? String(contentsOf: status.path, encoding: .utf8)
        else { return true }
        return !body.contains("version: \(version(for: skillName))")
    }

    public static func version(for skillName: AgentSkillName) -> String {
        switch skillName {
        case .vibevault: return AgentSkillContent.version
        case .lunaVaultAgentCoordination: return CoordinationSkillContent.version
        }
    }

    /// Prefer repo skill files when developing from source.
    public static func loadSkillFromRepo(
        root: URL,
        skillName: AgentSkillName = .vibevault
    ) -> String? {
        let file = skillName.repoPath(relativeTo: root)
        return try? String(contentsOf: file, encoding: .utf8)
    }
}
