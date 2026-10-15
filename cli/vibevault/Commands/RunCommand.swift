import ArgumentParser
import Foundation
import VaultCore

struct RunCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "run",
        abstract: "Run a command with secrets injected as environment variables.",
        usage: "vibevault run [--only NAME] [--exclude NAME] -- <command> [args...]"
    )

    @Option(name: .long, parsing: .upToNextOption, help: "Only inject these named secrets.") var only: [String] = []
    @Option(name: .long, parsing: .upToNextOption, help: "Exclude these named secrets.") var exclude: [String] = []
    @Argument(parsing: .captureForPassthrough, help: "Command to run.") var command: [String] = []

    mutating func run() async throws {
        guard !command.isEmpty else {
            FileHandle.standardError.write(Data("error: missing command after --\n".utf8))
            throw ExitCode(64)
        }
        // ArgumentParser may leave the "--" separator in the passthrough argv.
        let argv = command.first == "--" ? Array(command.dropFirst()) : command
        guard !argv.isEmpty else {
            FileHandle.standardError.write(Data("error: missing command after --\n".utf8))
            throw ExitCode(64)
        }
        let service = try VaultService.live()
        let listed = try service.list()
        let names = listed.map(\.name)
        let onlySet = Set(only)
        let excludeSet = Set(exclude)
        var selected = names.filter { name in
            (onlySet.isEmpty || onlySet.contains(name)) && !excludeSet.contains(name)
        }
        let agent = AgentDetector().detect()
        let blocked = MCPAllowlist.blockedNames(selected, secrets: listed, agent: agent)
        if !blocked.isEmpty {
            if !only.isEmpty {
                FileHandle.standardError.write(Data(
                    "error: not AI-allowed: \(blocked.sorted().joined(separator: ", ")). Enable AI access in the Vibe Vault app.\n".utf8
                ))
                throw ExitCode(2)
            }
            FileHandle.standardError.write(Data(
                "skipping secrets not allowed for AI agents: \(blocked.sorted().joined(separator: ", "))\n".utf8
            ))
            selected = selected.filter { !Set(blocked).contains($0) }
        }
        var env = ProcessInfo.processInfo.environment
        for name in selected {
            let secret = try await service.read(name: name, reason: "Inject \(name) for \(argv[0])")
            env[name] = secret.value
        }
        let exitCode = try EnvInjector.spawn(args: argv, env: env)
        if exitCode != 0 { throw ExitCode(Int32(exitCode)) }
    }
}
