import ArgumentParser
import Foundation
import VaultCore

struct GuardCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "guard",
        abstract: "Install or check git pre-commit hooks that block .env commits.",
        subcommands: [Install.self, Status.self],
        defaultSubcommand: Status.self
    )

    struct Install: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "install",
            abstract: "Install vibe-vault pre-commit guard in the current (or given) repo."
        )
        @Option(name: .shortAndLong, help: "Project directory (default: current).") var path: String?

        mutating func run() async throws {
            let url = URL(fileURLWithPath: path ?? FileManager.default.currentDirectoryPath)
            try PreCommitGuard.install(projectURL: url)
            print("Installed pre-commit guard at \(PreCommitGuard.hookURL(projectURL: url).path)")
        }
    }

    struct Status: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "status",
            abstract: "Show whether the pre-commit guard is installed."
        )
        @Option(name: .shortAndLong, help: "Project directory (default: current).") var path: String?

        mutating func run() async throws {
            let url = URL(fileURLWithPath: path ?? FileManager.default.currentDirectoryPath)
            if PreCommitGuard.isInstalled(projectURL: url) {
                print("guard: installed")
            } else {
                print("guard: not installed")
                throw ExitCode(1)
            }
        }
    }
}
