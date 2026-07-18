import ArgumentParser
import Foundation
import VaultCore

struct CursorCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "cursor",
        abstract: "Cursor-specific setup: rules, prepare project, MCP health.",
        subcommands: [
            CursorPrepareCommand.self,
            CursorRulesCommand.self,
            CursorShadowCommand.self
        ],
        defaultSubcommand: CursorPrepareCommand.self
    )
}

struct CursorPrepareCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "prepare",
        abstract: "Install Cursor rules, skill, MCP, and pre-commit guard for a project."
    )

    @Option(name: .shortAndLong, help: "Project directory (default: current).")
    var path: String?

    @Flag(name: .long, help: "Skip pre-commit guard.")
    var skipGuard = false

    mutating func run() async throws {
        let url = URL(fileURLWithPath: path ?? FileManager.default.currentDirectoryPath)
        let binary = locateMCPBinary()
        let result = try CursorProjectPrep.prepare(
            projectURL: url,
            mcpBinaryPath: binary,
            installGuard: !skipGuard
        )
        for line in result.messages { print(line) }
        print("done: prepare for Cursor at \(url.path)")
    }

    private func locateMCPBinary() -> String? {
        let bundled = Bundle.main.bundleURL
            .appendingPathComponent("Contents/MacOS/vibevault-mcp").path
        if FileManager.default.isExecutableFile(atPath: bundled) { return bundled }
        let candidates = [
            ".build/release/vibevault-mcp",
            ".build/debug/vibevault-mcp",
            "/usr/local/bin/vibevault-mcp"
        ]
        let cwd = FileManager.default.currentDirectoryPath
        for c in candidates {
            let p = (c as NSString).isAbsolutePath ? c : (cwd as NSString).appendingPathComponent(c)
            if FileManager.default.isExecutableFile(atPath: p) { return p }
        }
        return nil
    }
}

struct CursorRulesCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "rules",
        abstract: "Install or check `.cursor/rules/vibevault.mdc`."
    )

    @Option(name: .shortAndLong, help: "Project directory (default: current).")
    var path: String?

    @Flag(name: .long, help: "Only check status.")
    var status = false

    mutating func run() async throws {
        let url = URL(fileURLWithPath: path ?? FileManager.default.currentDirectoryPath)
        if status {
            let installed = CursorRulesInstaller.isInstalled(projectURL: url)
            let update = CursorRulesInstaller.needsUpdate(projectURL: url)
            if !installed { print("rules: missing"); throw ExitCode(1) }
            print(update ? "rules: outdated" : "rules: current (\(CursorRulesInstaller.version))")
            if update { throw ExitCode(2) }
            return
        }
        try CursorRulesInstaller.install(projectURL: url)
        print("installed \(CursorRulesInstaller.rulesURL(projectURL: url).path)")
    }
}

struct CursorShadowCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "shadow",
        abstract: "List MCP servers in ~/.cursor/mcp.json and flag non–vibe-vault entries."
    )

    mutating func run() async throws {
        let report = ShadowMCPScanner.scan(client: .cursor)
        if !report.configExists {
            print("cursor mcp.json: missing")
            throw ExitCode(1)
        }
        print("vibe-vault: \(report.vibeVaultInstalled ? "installed" : "NOT installed")")
        print("servers: \(report.servers.count) · shadow: \(report.shadowCount)")
        for s in report.servers {
            let tag = s.isVibeVault ? "ok" : "shadow"
            let cmd = s.command.map { " \($0)" } ?? ""
            print("  [\(tag)] \(s.name)\(cmd)")
        }
        if !report.vibeVaultInstalled { throw ExitCode(2) }
    }
}
