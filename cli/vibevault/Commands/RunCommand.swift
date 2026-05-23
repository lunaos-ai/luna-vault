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
