import ArgumentParser
import Foundation
import VaultCore

struct SkillCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "skill",
        abstract: "Install the Vibe Vault agent skill for Cursor and Claude.",
        subcommands: [SkillInstallCommand.self, SkillStatusCommand.self]
    )
}

struct SkillInstallCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(commandName: "install")

    @Option(name: .long, help: "Target: cursor, claude, windsurf, all.")
    var target: String = "all"

    mutating func run() async throws {
        let content = resolveContent()
        let targets = try resolveTargets(target)
        for t in targets { try AgentSkillInstaller.install(target: t, content: content) }
        print("installed skill to \(targets.map { $0.installDirectory.path }.joined(separator: ", "))")
    }

    private func resolveTargets(_ raw: String) throws -> [AgentSkillTarget] {
        if raw == "all" { return Array(AgentSkillTarget.allCases) }
        guard let t = AgentSkillTarget(rawValue: raw) else {
            throw ValidationError("unknown target: \(raw)")
        }
        return [t]
    }

    private func resolveContent() -> String {
        let cwd = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        if let c = AgentSkillInstaller.loadSkillFromRepo(root: cwd) { return c }
        let repo = URL(fileURLWithPath: #file)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        if let c = AgentSkillInstaller.loadSkillFromRepo(root: repo) { return c }
        return AgentSkillInstaller.bundledSkillContent()
    }
}

struct SkillStatusCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(commandName: "status")

    mutating func run() async throws {
        for t in AgentSkillTarget.allCases {
            let s = AgentSkillInstaller.status(of: t)
            let state = s.installed ? "installed" : "missing"
            print("\(t.displayName.padding(toLength: 10, withPad: " ", startingAt: 0)) \(state)  \(s.path.path)")
        }
    }
}
