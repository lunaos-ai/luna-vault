import ArgumentParser
import Foundation
import VaultCore

struct AgentsCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "agents",
        abstract: "Install policy files that tell AI agents to use Vibe Vault.",
        subcommands: [AgentsPrepareCommand.self, AgentsStatusCommand.self],
        defaultSubcommand: AgentsPrepareCommand.self
    )
}

struct AgentsPrepareCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "prepare",
        abstract: "Install AGENTS.md, CLAUDE.md, GEMINI.md, and Cursor rules."
    )

    @Option(name: .shortAndLong, help: "Project directory (default: current).")
    var path: String?

    @Option(name: .long, help: "Target: all, codex, claude, gemini, cursor.")
    var target: String = "all"

    @Flag(name: .long, help: "Skip project scan while writing policy files.")
    var skipScan = false

    mutating func run() async throws {
        let url = URL(fileURLWithPath: path ?? FileManager.default.currentDirectoryPath)
        let scan = skipScan ? nil : try? ProjectScanner().scan(projectURL: url, knownSecrets: [])
        let targets = try resolveTargets(target)
        for target in targets {
            let result = try AgentPolicyInstaller.install(projectURL: url, target: target, scan: scan)
            print("installed \(result.target.displayName): \(result.path)")
        }
        print("done: agent policies at \(url.path)")
    }
}

struct AgentsStatusCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(commandName: "status")

    @Option(name: .shortAndLong, help: "Project directory (default: current).")
    var path: String?

    @Option(name: .long, help: "Target: all, codex, claude, gemini, cursor.")
    var target: String = "all"

    mutating func run() async throws {
        let url = URL(fileURLWithPath: path ?? FileManager.default.currentDirectoryPath)
        for target in try resolveTargets(target) {
            let status = AgentPolicyInstaller.status(projectURL: url, target: target)
            let state = status.installed ? (status.needsUpdate ? "outdated" : "installed") : "missing"
            print("\(target.rawValue.padding(toLength: 8, withPad: " ", startingAt: 0)) \(state)  \(status.path)")
        }
    }
}

private func resolveTargets(_ raw: String) throws -> [AgentPolicyTarget] {
    if raw == "all" { return AgentPolicyTarget.allCases }
    guard let target = AgentPolicyTarget(rawValue: raw) else {
        throw ValidationError("unknown target: \(raw)")
    }
    return [target]
}
