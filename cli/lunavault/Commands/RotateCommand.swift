import ArgumentParser
import Foundation
import VaultCore

struct RotateCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "rotate",
        abstract: "Rotate a secret (record rotation; optionally update value)."
    )

    @Argument(help: "Secret name to rotate.") var name: String

    @Option(name: .shortAndLong, help: "New value. If omitted with --mark-only, just records rotation.") var value: String?

    @Flag(name: .long, help: "Just record rotation timestamp; do not change value.") var markOnly = false

    mutating func run() async throws {
        let service = try VaultService.live()
        let newValue: String?
        if markOnly {
            newValue = nil
        } else if let v = value {
            newValue = v
        } else {
            FileHandle.standardError.write(Data("Enter new value for \(name): ".utf8))
            guard let line = readLine(), !line.isEmpty else {
                FileHandle.standardError.write(Data("aborted (empty value); use --mark-only to record without changing\n".utf8))
                throw ExitCode(64)
            }
            newValue = line
        }
        do {
            try await service.rotate(name: name, newValue: newValue)
            print(markOnly ? "rotation recorded for \(name)" : "rotated \(name)")
        } catch SecretError.notFound {
            FileHandle.standardError.write(Data("secret '\(name)' not found\n".utf8))
            throw ExitCode(2)
        }
    }
}
