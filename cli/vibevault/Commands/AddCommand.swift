import ArgumentParser
import Foundation
import VaultCore

struct AddCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(commandName: "add", abstract: "Add a new secret to the vault.")

    @Argument(help: "Secret name (e.g. CF_API_TOKEN).") var name: String

    @Option(name: .shortAndLong, help: "Secret value. If omitted, read from stdin.") var value: String?

    @Option(name: .shortAndLong, help: "Optional notes.") var notes: String?

    @Option(name: .long, help: "Expiry as ISO-8601 date or duration like 30d, 12w, 6mo.") var expires: String?

    @Option(name: .long, help: "Rotate every N days (records rotation due-date).") var rotateEvery: Int?

    @Flag(name: .long, help: "Update if the secret already exists.") var upsert = false

    mutating func run() async throws {
        let service = try VaultService.live()
        let secretValue = try resolveValue()
        let expiresAt = try expires.map { try parseExpiry($0) }
        do {
            try service.add(name: name, value: secretValue, notes: notes, expiresAt: expiresAt, rotateEveryDays: rotateEvery)
            print("added \(name)")
        } catch SecretError.duplicate where upsert {
            try service.update(name: name, value: secretValue, notes: notes, expiresAt: expiresAt, rotateEveryDays: rotateEvery)
            print("updated \(name)")
        } catch SecretError.duplicate {
            FileHandle.standardError.write(Data("secret '\(name)' already exists. Use --upsert to overwrite.\n".utf8))
            throw ExitCode(2)
        }
    }

    private func parseExpiry(_ s: String) throws -> Date {
        let trimmed = s.trimmingCharacters(in: .whitespaces)
        if let date = ISO8601DateFormatter().date(from: trimmed) { return date }
        // duration: <int><d|w|mo|y>
        let unitMap: [(String, Int)] = [("mo", 30), ("y", 365), ("w", 7), ("d", 1)]
        for (suffix, daysPerUnit) in unitMap where trimmed.hasSuffix(suffix) {
            let numPart = String(trimmed.dropLast(suffix.count))
            if let n = Int(numPart), n > 0 {
                return Calendar.current.date(byAdding: .day, value: n * daysPerUnit, to: Date()) ?? Date()
            }
        }
        throw ValidationError("invalid --expires; use ISO-8601 date or 30d/12w/6mo/1y")
    }

    private func resolveValue() throws -> String {
        if let v = value { return v }
        FileHandle.standardError.write(Data("Enter value for \(name) (input hidden via terminal): ".utf8))
        guard let line = readLine() else { throw ValidationError("no value provided") }
        return line
    }
}
