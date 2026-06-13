import ArgumentParser
import Foundation
import VaultCore

struct ExportCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "export",
        abstract: "Export secrets to a project .env file (with optional git guard)."
    )

    @Argument(help: "Secret names to export. Omit to export all.") var names: [String] = []

    @Option(name: [.customShort("f"), .long], help: "Target .env file path.") var file: String = ".env"

    @Flag(name: .long, help: "Overwrite the file instead of merging existing keys.") var overwrite = false

    @Flag(name: .long, help: "Skip the .gitignore entry and pre-commit hook.") var noGuard = false

    mutating func run() async throws {
        let service = try VaultService.live()
        let targets = names.isEmpty ? try service.list().map(\.name) : names
        guard !targets.isEmpty else {
            FileHandle.standardError.write(Data("no secrets to export\n".utf8))
            throw ExitCode(2)
        }

        var pairs: [(name: String, value: String)] = []
        for n in targets {
            do {
                let s = try await service.read(name: n, reason: "Export \(n) to .env")
                pairs.append((s.name, s.value))
            } catch SecretError.notFound {
                FileHandle.standardError.write(Data("secret '\(n)' not found\n".utf8))
                throw ExitCode(2)
            }
        }

        let url = URL(fileURLWithPath: file)
        let result = try DotenvWriter.write(secrets: pairs, to: url, mode: overwrite ? .overwrite : .merge)
        try? service.recordEvent(
            name: url.lastPathComponent, action: .export, projectPath: service.currentProjectPath())

        var msg = "wrote \(result.written.count) secret\(result.written.count == 1 ? "" : "s") → \(result.path)"
        if !noGuard {
            let project = url.deletingLastPathComponent()
            _ = try? GitGuard.ensureGitignore(projectURL: project)
            if let hook = try? GitGuard.installPrecommitHook(projectURL: project) {
                msg += hook == .skippedForeignHook
                    ? " (kept existing pre-commit hook)"
                    : " (git guard active)"
            }
        }
        print(msg)
    }
}
