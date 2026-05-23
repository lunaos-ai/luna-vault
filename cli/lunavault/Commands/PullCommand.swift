import ArgumentParser
import Foundation
import VaultCore

struct PullCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "pull",
        abstract: "Pull secret names (and values where supported) from a provider."
    )

    @Option(name: .long, help: "Provider id (cloudflare, vercel, pushci).") var from: String
    @Option(name: .long, parsing: .upToNextOption, help: "Scope key=value pairs.") var scope: [String] = []
    @Flag(name: .long, help: "Import pulled secrets into local vault (requires values).") var importSecrets = false

    mutating func run() async throws {
        let registry = ProviderRegistry.defaults()
        guard let provider = registry.provider(id: from) else {
            FileHandle.standardError.write(Data("unknown provider: \(from)\n".utf8))
            throw ExitCode(2)
        }
        var scopeMap: [String: String] = [:]
        for pair in scope {
            let parts = pair.split(separator: "=", maxSplits: 1).map(String.init)
            if parts.count == 2 { scopeMap[parts[0]] = parts[1] }
        }
        let target = ProviderTarget(provider: from, scope: scopeMap)
        let secrets = try await provider.pull(target: target)
        if importSecrets {
            let service = try VaultService.live()
            var imported = 0
            for s in secrets where !s.value.isEmpty {
                do {
                    try service.add(name: s.name, value: s.value, notes: "imported from \(provider.displayName)")
                    imported += 1
                } catch SecretError.duplicate {
                    try service.update(name: s.name, value: s.value, notes: "updated from \(provider.displayName)")
                    imported += 1
                }
            }
            print("imported \(imported) of \(secrets.count) secrets")
        } else {
            for s in secrets {
                print(s.value.isEmpty ? "\(s.name)  (value not retrievable from \(provider.displayName))" : "\(s.name)=\(s.maskedValue)")
            }
        }
    }
}
