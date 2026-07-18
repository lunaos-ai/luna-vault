import ArgumentParser
import Foundation
import VaultCore

struct MCPCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "mcp",
        abstract: "Install and test the Vibe Vault MCP server for AI clients.",
        subcommands: [MCPStatusCommand.self, MCPInstallCommand.self, MCPTestCommand.self]
    )
}

struct MCPStatusCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(commandName: "status", abstract: "Show MCP install status per client.")

    mutating func run() async throws {
        for client in MCPClientID.allCases {
            let s = MCPClientInstaller.status(of: client)
            let state = s.installed ? "installed" : (s.parentDirExists ? "detected" : "missing")
            print("\(client.displayName.padding(toLength: 14, withPad: " ", startingAt: 0)) \(state)  \(client.configHint)")
        }
    }
}

struct MCPInstallCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(commandName: "install", abstract: "Install MCP config for AI clients.")

    @Option(name: .long, help: "Client id: cursor, vscode, devin, claude-code, windsurf, claude-desktop, all.")
    var client: String = "all"

    @Option(name: .long, help: "Path to vibevault-mcp binary.")
    var binary: String?

    mutating func run() async throws {
        let path = binary ?? resolveBinary()
        guard FileManager.default.isExecutableFile(atPath: path) else {
            FileHandle.standardError.write(Data("vibevault-mcp not found at \(path)\n".utf8))
            throw ExitCode(2)
        }
        let targets = try targets(for: client)
        for t in targets {
            try MCPClientInstaller.install(client: t, binaryPath: path)
            print("installed \(t.displayName) → \(t.configHint)")
        }
    }

    private func targets(for raw: String) throws -> [MCPClientID] {
        if raw == "all" { return Array(MCPClientID.allCases) }
        guard let id = MCPClientID(rawValue: raw) else {
            throw ValidationError("unknown client: \(raw)")
        }
        return [id]
    }

    private func resolveBinary() -> String {
        let exe = URL(fileURLWithPath: CommandLine.arguments[0])
        let sibling = exe.deletingLastPathComponent().appendingPathComponent("vibevault-mcp").path
        if FileManager.default.isExecutableFile(atPath: sibling) { return sibling }
        return "/usr/local/bin/vibevault-mcp"
    }
}

struct MCPTestCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(commandName: "test", abstract: "Ping the MCP server over stdio.")

    @Option(name: .long, help: "Path to vibevault-mcp binary.")
    var binary: String?

    mutating func run() async throws {
        let path = binary ?? URL(fileURLWithPath: CommandLine.arguments[0])
            .deletingLastPathComponent().appendingPathComponent("vibevault-mcp").path
        let ok = try await ping(binary: path)
        if ok { print("MCP server OK") } else { throw ExitCode(1) }
    }

    private func ping(binary: String) async throws -> Bool {
        let process = Process()
        let pipeIn = Pipe()
        let pipeOut = Pipe()
        process.executableURL = URL(fileURLWithPath: binary)
        process.standardInput = pipeIn
        process.standardOutput = pipeOut
        process.standardError = Pipe()
        try process.run()
        let req = "{\"jsonrpc\":\"2.0\",\"id\":1,\"method\":\"tools/list\",\"params\":{}}\n"
        pipeIn.fileHandleForWriting.write(Data(req.utf8))
        pipeIn.fileHandleForWriting.closeFile()
        let out = pipeOut.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        let text = String(data: out, encoding: .utf8) ?? ""
        return process.terminationStatus == 0 && text.contains("list_secrets")
    }
}
