import ArgumentParser
import Foundation
import VaultCore

struct ProjectsCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "projects",
        abstract: "List, add, or remove remembered project folders.",
        subcommands: [List.self, Add.self, Remove.self],
        defaultSubcommand: List.self
    )

    struct List: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "list",
            abstract: "Show remembered projects and last scan counts."
        )

        mutating func run() async throws {
            let rows = ProjectRegistry().list()
            if rows.isEmpty {
                print("No remembered projects. Scan one with: vibevault scan --path /project")
                return
            }
            for row in rows {
                let mark = row.id == ProjectRegistry().selectedID ? "*" : " "
                let status: String
                switch row.access {
                case .ready: status = "ok"
                case .missing: status = "missing"
                case .notDirectory: status = "not-a-folder"
                }
                let missing = row.missingCount > 0 ? " missing=\(row.missingCount)" : ""
                let leaks = row.leakCount > 0 ? " leaks=\(row.leakCount)" : ""
                print("\(mark) \(row.name)  \(status)\(missing)\(leaks)")
                print("    \(row.path)")
            }
        }
    }

    struct Add: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "add",
            abstract: "Remember a project folder without scanning."
        )
        @Option(name: .shortAndLong, help: "Project directory (default: current).")
        var path: String?

        mutating func run() async throws {
            let url = URL(fileURLWithPath: path ?? FileManager.default.currentDirectoryPath)
            try ProjectScanner.validateRoot(url)
            let record = try ProjectRegistry().upsert(url: url)
            print("remembered \(record.name)")
            print(record.path)
        }
    }

    struct Remove: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "remove",
            abstract: "Forget a remembered project folder."
        )
        @Argument(help: "Project name or path.")
        var name: String

        mutating func run() async throws {
            let registry = ProjectRegistry()
            let needle = name.lowercased()
            guard let row = registry.list().first(where: {
                $0.name.lowercased() == needle || $0.path == name
            }) else {
                FileHandle.standardError.write(Data("project '\(name)' not found\n".utf8))
                throw ExitCode(2)
            }
            try registry.remove(id: row.id)
            print("forgot \(row.name)")
        }
    }
}
