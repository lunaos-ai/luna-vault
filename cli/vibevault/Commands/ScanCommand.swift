import ArgumentParser
import Foundation
import VaultCore

struct ScanCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "scan",
        abstract: "Scan a project for required secrets and report missing/extra."
    )

    @Option(name: .shortAndLong, help: "Project directory (default: current).") var path: String?
    @Flag(name: .long, help: "Output as JSON.") var json = false

    mutating func run() async throws {
        let service = try VaultService.live()
        let projectURL = URL(fileURLWithPath: path ?? FileManager.default.currentDirectoryPath)
        let known = Set(try service.list().map(\.name))
        let scanner = ProjectScanner()
        let result = try scanner.scan(projectURL: projectURL, knownSecrets: known)
        if json {
            let payload: [String: Any] = [
                "required": Array(result.required).sorted(),
                "missing": Array(result.missing).sorted(),
                "extra": Array(result.extra).sorted(),
                "sources": result.sources
            ]
            let data = try JSONSerialization.data(withJSONObject: payload, options: [.prettyPrinted])
            print(String(data: data, encoding: .utf8) ?? "{}")
        } else {
            print("Scanned: \(projectURL.path)")
            print("Required (\(result.required.count)): \(Array(result.required).sorted().joined(separator: ", "))")
            print("Missing  (\(result.missing.count)): \(Array(result.missing).sorted().joined(separator: ", "))")
            print("Extra    (\(result.extra.count)): \(Array(result.extra).sorted().joined(separator: ", "))")
        }
        if !result.missing.isEmpty { throw ExitCode(3) }
    }
}
