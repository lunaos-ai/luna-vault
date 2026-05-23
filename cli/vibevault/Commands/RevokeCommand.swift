import ArgumentParser
import Foundation
import VaultCore

struct RevokeCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "revoke",
        abstract: "Delete a secret from the vault (does not revoke at provider)."
    )

    @Argument(help: "Secret name to revoke.") var name: String
    @Flag(name: .long, help: "Skip confirmation prompt.") var yes = false

    mutating func run() async throws {
        let service = try VaultService.live()
        if !yes {
            FileHandle.standardError.write(Data("Delete secret '\(name)' from local vault? [y/N] ".utf8))
            guard let line = readLine(), line.lowercased().hasPrefix("y") else {
                print("cancelled")
                return
            }
        }
        do {
            try service.delete(name: name)
            print("revoked \(name)")
        } catch SecretError.notFound {
            FileHandle.standardError.write(Data("secret '\(name)' not found\n".utf8))
            throw ExitCode(2)
        }
    }
}
