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
    @Flag(name: .long, help: "Dry-run; print what would be pushed.") var dryRun = false

    mutating func run() async throws {
        let service = try VaultService.live()
        let registry = ProviderRegistry.defaults()
        guard let provider = registry.provider(id: to) else {
            FileHandle.standardError.write(Data("unknown provider: \(to)\n".utf8))
            throw ExitCode(2)
        }
        let target = try buildTarget(provider: to)
        let names = name.isEmpty ? try service.list().map(\.name) : name
        var secrets: [Secret] = []
        for n in names {
            let s = try await service.read(name: n, reason: "Push \(n) to \(provider.displayName)")
            secrets.append(s)
            try service.recordEvent(name: n, action: .push, projectPath: service.currentProjectPath())
        }
        if dryRun {
            print("[dry-run] would push \(secrets.count) secrets to \(provider.displayName)")
            for s in secrets { print("  - \(s.name)") }
            return
        }
        let result = try await provider.push(secrets: secrets, target: target)
        print("pushed \(result.pushed.count): \(result.pushed.joined(separator: ", "))")
        if !result.failed.isEmpty {
            for f in result.failed {
                FileHandle.standardError.write(Data("failed \(f.name): \(f.reason)\n".utf8))
            }
            throw ExitCode(4)
        }
    }

    private func buildTarget(provider: String) throws -> ProviderTarget {
        var scopeMap: [String: String] = [:]
        for pair in scope {
            let parts = pair.split(separator: "=", maxSplits: 1).map(String.init)
            guard parts.count == 2 else { throw ValidationError("invalid scope pair: \(pair) (use key=value)") }
            scopeMap[parts[0]] = parts[1]
        }
        return ProviderTarget(provider: provider, scope: scopeMap)
    }
}
