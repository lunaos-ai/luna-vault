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

    public var installDirectory: URL {
        let home = FileManager.default.homeDirectoryForCurrentUser
        switch self {
        case .cursor: return home.appendingPathComponent(".cursor/skills/vibevault")
        case .claude: return home.appendingPathComponent(".claude/skills/vibevault")
        case .devin: return home.appendingPathComponent(".devin/skills/vibevault")
        }
    }
}

public struct AgentSkillStatus: Equatable, Sendable {
    public let target: AgentSkillTarget
    public let installed: Bool
    public let path: URL

    public init(target: AgentSkillTarget, installed: Bool, path: URL) {
        self.target = target
        self.installed = installed
        self.path = path
    }
}

public enum AgentSkillInstaller {
    public static let skillFileName = "SKILL.md"

    public static func bundledSkillContent() -> String {
        AgentSkillContent.markdown
    }

    public static func status(of target: AgentSkillTarget) -> AgentSkillStatus {
        let dir = target.installDirectory
        let file = dir.appendingPathComponent(skillFileName)
        return AgentSkillStatus(
            target: target,
            installed: FileManager.default.fileExists(atPath: file.path),
            path: file
        )
    }

    public static func install(target: AgentSkillTarget, content: String? = nil) throws {
        let dir = target.installDirectory
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let body = content ?? bundledSkillContent()
        try body.write(to: dir.appendingPathComponent(skillFileName), atomically: true, encoding: .utf8)
    }

    public static func installAll(content: String? = nil) throws {
        for target in AgentSkillTarget.allCases {
            try install(target: target, content: content)
        }
    }

    public static func uninstall(target: AgentSkillTarget) throws {
        let dir = target.installDirectory
        if FileManager.default.fileExists(atPath: dir.path) {
            try FileManager.default.removeItem(at: dir)
        }
    }

    public static func isOutdated(target: AgentSkillTarget) -> Bool {
        let status = status(of: target)
        guard status.installed,
              let body = try? String(contentsOf: status.path, encoding: .utf8)
        else { return true }
        return !body.contains("version: \(AgentSkillContent.version)")
    }

    /// Prefer repo `skills/vibevault/SKILL.md` when developing from source.
    public static func loadSkillFromRepo(root: URL) -> String? {
        let file = root.appendingPathComponent("skills/vibevault/SKILL.md")
        return try? String(contentsOf: file, encoding: .utf8)
    }
}
