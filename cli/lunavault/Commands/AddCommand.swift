import ArgumentParser
import Foundation
import VaultCore

struct AddCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(commandName: "add", abstract: "Add a new secret to the vault.")

    @Argument(help: "Secret name (e.g. CF_API_TOKEN).") var name: String

    @Option(name: .shortAndLong, help: "Secret value. If omitted, read from stdin.") var value: String?

    @Option(name: .shortAndLong, help: "Optional notes.") var notes: String?

    @Flag(name: .long, help: "Update if the secret already exists.") var upsert = false

    mutating func run() async throws {
        let service = try VaultService.live()
        let secretValue = try resolveValue()
        do {
            try service.add(name: name, value: secretValue, notes: notes)
            print("added \(name)")
        } catch SecretError.duplicate where upsert {
            try service.update(name: name, value: secretValue, notes: notes)
            print("updated \(name)")
        } catch SecretError.duplicate {
            FileHandle.standardError.write(Data("secret '\(name)' already exists. Use --upsert to overwrite.\n".utf8))
            throw ExitCode(2)
        }
    }

    private func resolveValue() throws -> String {
        if let v = value { return v }
        FileHandle.standardError.write(Data("Enter value for \(name) (input hidden via terminal): ".utf8))
        guard let line = readLine() else { throw ValidationError("no value provided") }
        return line
    }
}
