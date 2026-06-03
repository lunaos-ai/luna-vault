import Foundation

public enum ProjectMissingImporter {
    public struct Result {
        public let items: [VaultService.ImportItem]
        public let stillMissing: Set<String>
        public init(items: [VaultService.ImportItem], stillMissing: Set<String>) {
            self.items = items
            self.stillMissing = stillMissing
        }
    }

    static let candidateDotenvs: [String] = [
        ".env.local",
        ".env.development.local",
        ".env.production.local",
        ".env.development",
        ".env.production",
        ".env"
    ]

    public static func collect(
        projectURL: URL,
        missing: Set<String>,
        fileManager: FileManager = .default
    ) -> Result {
        guard !missing.isEmpty else {
            return Result(items: [], stillMissing: [])
        }
        var values: [String: String] = [:]
        for name in candidateDotenvs {
            let url = projectURL.appendingPathComponent(name)
            guard fileManager.fileExists(atPath: url.path),
                  let content = try? String(contentsOf: url, encoding: .utf8) else { continue }
            for item in DotenvImporter.parse(content) where values[item.name] == nil {
                values[item.name] = item.value
            }
        }
        var items: [VaultService.ImportItem] = []
        var stillMissing = Set<String>()
        for name in missing {
            if let v = values[name], !v.isEmpty, !isPlaceholder(v) {
                items.append(VaultService.ImportItem(
                    name: name, value: v, notes: "imported from project dotenv"
                ))
            } else {
                stillMissing.insert(name)
            }
        }
        return Result(items: items, stillMissing: stillMissing)
    }

    static func isPlaceholder(_ v: String) -> Bool {
        let t = v.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if t.isEmpty { return true }
        if t.hasPrefix("your-") || t.hasPrefix("your_") { return true }
        if t.hasPrefix("<") && t.hasSuffix(">") { return true }
        let bad: Set<String> = ["changeme", "placeholder", "todo", "xxx", "xxxx", "example"]
        return bad.contains(t)
    }
}
