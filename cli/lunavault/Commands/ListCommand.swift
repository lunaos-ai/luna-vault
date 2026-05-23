import ArgumentParser
import Foundation
import VaultCore

struct ListCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(commandName: "list", abstract: "List secrets in the vault.")

    @Flag(name: .long, help: "Output as JSON.") var json = false

    mutating func run() async throws {
        let service = try VaultService.live()
        let secrets = try service.list().sorted { $0.name < $1.name }
        if json {
            let payload = secrets.map { ["name": $0.name, "updated": ISO8601DateFormatter().string(from: $0.updatedAt)] }
            let data = try JSONSerialization.data(withJSONObject: payload, options: [.prettyPrinted])
            print(String(data: data, encoding: .utf8) ?? "[]")
        } else if secrets.isEmpty {
            print("(no secrets)")
        } else {
            let nameWidth = max(4, secrets.map(\.name.count).max() ?? 0)
            let header = "NAME".padding(toLength: nameWidth, withPad: " ", startingAt: 0) + "  UPDATED              STATUS"
            print(header)
            print(String(repeating: "-", count: header.count))
            let fmt = DateFormatter()
            fmt.dateStyle = .short
            fmt.timeStyle = .short
            for s in secrets {
                let line = s.name.padding(toLength: nameWidth, withPad: " ", startingAt: 0)
                    + "  " + fmt.string(from: s.updatedAt).padding(toLength: 20, withPad: " ", startingAt: 0)
                    + status(for: s)
                print(line)
            }
        }
    }

    private func status(for s: Secret) -> String {
        var parts: [String] = []
        if s.isExpired { parts.append("expired") }
        else if let exp = s.expiresAt {
            let days = Calendar.current.dateComponents([.day], from: Date(), to: exp).day ?? 0
            parts.append("expires in \(days)d")
        }
        if s.isRotationDue { parts.append("rotate due") }
        return parts.isEmpty ? "ok" : parts.joined(separator: ", ")
    }
}
