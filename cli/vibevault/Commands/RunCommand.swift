import ArgumentParser
import Foundation
import VaultCore

struct RunCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "run",
        abstract: "Run a command with secrets injected as environment variables.",
        usage: "vibevault run [--only NAME] [--exclude NAME] -- <command> [args...]",
        discussion: """
        Prefer injection over retrieval. Select only the secrets the child
        process needs:

          vibevault run --only GHCR_TOKEN -- your-command

        Map a secret to the name expected by a child tool without printing it:

          vibevault run --only GHCR_TOKEN -- \\
            sh -c 'GH_TOKEN="$GHCR_TOKEN" exec gh auth status'

        When the user explicitly needs the raw value, prefer the clipboard:

          vibevault run --only GHCR_TOKEN -- \\
            sh -c 'printf %s "$GHCR_TOKEN" | pbcopy'

        `printenv GHCR_TOKEN` prints the value into terminal or agent output and
        should be used only with explicit user approval.

        This command needs local access to the same Mac, user, and macOS
        Keychain context as Vibe Vault. If Terminal works but an agent sandbox
        fails, request approved host-level execution; never reset the vault
        master key.
        """
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
        let names = try service.list().map(\.name)
        let onlySet = Set(only)
        let excludeSet = Set(exclude)
        let selected = names.filter { name in
            (onlySet.isEmpty || onlySet.contains(name)) && !excludeSet.contains(name)
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
