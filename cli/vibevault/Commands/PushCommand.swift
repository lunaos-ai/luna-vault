import ArgumentParser
import Foundation
import VaultCore

struct PushCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "push",
        abstract: "Push selected secrets to a cloud provider."
    )

    @Option(name: .long, help: "Provider id (cloudflare, vercel, pushci).") var to: String
    @Option(name: .long, parsing: .upToNextOption, help: "Secret names to push (default: all).") var name: [String] = []
    @Option(name: .long, parsing: .upToNextOption, help: "Scope key=value pairs (e.g. account_id=abc).") var scope: [String] = []
    @Option(name: .long, help: "Project directory for provider scope auto-detection.") var project: String?
    @Flag(name: .long, help: "Dry-run; print what would be pushed.") var dryRun = false

    mutating func run() async throws {
        let service = try VaultService.live()
        let prefs = KeychainPrefs()
        let registry = ProviderRegistry.defaultsWithToken(from: prefs)
        guard let provider = registry.provider(id: to) else {
            FileHandle.standardError.write(Data("unknown provider: \(to)\n".utf8))
            throw ExitCode(2)
        }
        let target = try ProviderScopeResolver.target(provider: to, pairs: scope, projectPath: project)
        let names = name.isEmpty ? try service.list().map(\.name) : name
        if dryRun {
            print("[dry-run] would push \(names.count) secrets to \(provider.displayName)")
            for name in names { print("  - \(name)") }
            return
        }
        var secrets: [Secret] = []
        for n in names {
            let s = try await service.read(name: n, reason: "Push \(n) to \(provider.displayName)")
            secrets.append(s)
        }
        let result = try await provider.push(secrets: secrets, target: target)
        for name in result.pushed {
            try service.recordEvent(name: name, action: .push, projectPath: service.currentProjectPath())
        }
        print("pushed \(result.pushed.count): \(result.pushed.joined(separator: ", "))")
        if !result.failed.isEmpty {
            for f in result.failed {
                FileHandle.standardError.write(Data("failed \(f.name): \(f.reason)\n".utf8))
            }
            throw ExitCode(4)
        }
    }
}
