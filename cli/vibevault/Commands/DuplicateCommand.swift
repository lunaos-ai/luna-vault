import ArgumentParser
import Foundation
import VaultCore

struct DuplicateCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "duplicate",
        abstract: "Copy a secret to NAME-copy. AI access starts off on the copy."
    )

    @Argument(help: "Secret name to duplicate.") var name: String

    mutating func run() async throws {
        let service = try VaultService.live()
        do {
            let copy = try await service.duplicate(name: name)
            print("duplicated \(name) as \(copy)")
        } catch SecretError.notFound {
            FileHandle.standardError.write(Data("secret '\(name)' not found\n".utf8))
            throw ExitCode(2)
        } catch SecretError.mcpDenied(let blocked) {
            FileHandle.standardError.write(Data("\(SecretError.mcpDenied(name: blocked))\n".utf8))
            throw ExitCode(2)
        }
    }
}
