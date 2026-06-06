import ArgumentParser
import Foundation
import VaultCore

struct RunCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "run",
        abstract: "Run a command with secrets injected as environment variables.",
        usage: "vibevault run [--only NAME] [--exclude NAME] -- <command> [args...]"
    )

    // Repeatable single-value options (`--only A --only B`). NOT `.upToNextOption`:
    // that strategy greedily swallows the trailing command (e.g. `--only X sh -c …`
    // captured `sh` into `only`, leaving `-c` as the command → "command not found: -c").
    @Option(name: .long, help: "Only inject these named secrets (repeatable).") var only: [String] = []
    @Option(name: .long, help: "Exclude these named secrets (repeatable).") var exclude: [String] = []
    @Argument(parsing: .captureForPassthrough, help: "Command to run after `--`.") var rawCommand: [String] = []

    /// The command to exec. `.captureForPassthrough` retains the leading `--`
    /// terminator, so strip a single one — otherwise EnvInjector tries to exec
    /// "--" and reports "command not found: --".
    var command: [String] {
        rawCommand.first == "--" ? Array(rawCommand.dropFirst()) : rawCommand
    }

    mutating func run() async throws {
        guard !command.isEmpty else {
            FileHandle.standardError.write(Data("error: missing command after --\n".utf8))
            throw ExitCode(64)
        }
        let service = try VaultService.live()
        let names = try service.list().map(\.name)
        let onlySet = Set(only)
        let excludeSet = Set(exclude)
        let selected = names.filter { name in
            (onlySet.isEmpty || onlySet.contains(name)) && !excludeSet.contains(name)
        }
        var env = ProcessInfo.processInfo.environment
        for name in selected {
            let secret = try await service.read(name: name, reason: "Inject \(name) for \(command[0])")
            env[name] = secret.value
        }
        let exitCode = try EnvInjector.spawn(args: command, env: env)
        if exitCode != 0 { throw ExitCode(Int32(exitCode)) }
    }
}
