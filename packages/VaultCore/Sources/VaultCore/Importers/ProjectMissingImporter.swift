import Foundation

public enum ProjectMissingImporter {
    public struct PreviewItem: Sendable, Equatable {
        public let sourceName: String
        public let value: String
        public let vaultName: String
        public let sourceFile: String?

        public init(sourceName: String, value: String, prefix: String, sourceFile: String? = nil) {
            self.sourceName = sourceName
            self.value = value
            self.vaultName = SecretNaming.applyPrefix(prefix, to: sourceName)
            self.sourceFile = sourceFile
        }
    }

    public struct Result {
        public let items: [VaultService.ImportItem]
        public let previews: [PreviewItem]
        public let stillMissing: Set<String>
        public init(
            items: [VaultService.ImportItem],
            previews: [PreviewItem],
            stillMissing: Set<String>
        ) {
            self.items = items
            self.previews = previews
            self.stillMissing = stillMissing
        }
    }

    public static func collect(
        projectURL: URL,
        missing: Set<String> = [],
        includeAllDotenv: Bool = true,
        prefix: String = "",
        excludingVaultNames: Set<String> = [],
        fileManager: FileManager = .default
    ) -> Result {
        let values = loadValuesWithSources(under: projectURL, fileManager: fileManager)
        let targetNames: Set<String>
        if includeAllDotenv {
            targetNames = missing.union(Set(values.keys))
        } else {
            targetNames = missing
        }
        guard !targetNames.isEmpty else {
            return Result(items: [], previews: [], stillMissing: [])
        }

        var items: [VaultService.ImportItem] = []
        var previews: [PreviewItem] = []
        var stillMissing = Set<String>()
        for name in targetNames.sorted() {
            let vaultName = SecretNaming.applyPrefix(prefix, to: name)
            if excludingVaultNames.contains(vaultName) { continue }
            if let entry = values[name], !entry.value.isEmpty, !isPlaceholder(entry.value) {
                previews.append(PreviewItem(
                    sourceName: name, value: entry.value, prefix: prefix, sourceFile: entry.file
                ))
                items.append(VaultService.ImportItem(
                    name: vaultName, value: entry.value, notes: dotenvNote(entry.file)
                ))
            } else if missing.contains(name) {
                stillMissing.insert(name)
            }
        }
        return Result(items: items, previews: previews, stillMissing: stillMissing)
    }

    private struct ValueSource {
        let value: String
        let file: String
    }

    private static func loadValuesWithSources(
        under root: URL,
        fileManager: FileManager
    ) -> [String: ValueSource] {
        var out: [String: ValueSource] = [:]
        let files = DotenvDiscovery.findFiles(under: root, fileManager: fileManager)
        let rootPath = root.path + "/"
        for url in files {
            guard let content = try? String(contentsOf: url, encoding: .utf8) else { continue }
            let rel = url.path.hasPrefix(rootPath)
                ? String(url.path.dropFirst(rootPath.count))
                : url.lastPathComponent
            for item in DotenvImporter.parse(content) {
                out[item.name] = ValueSource(value: item.value, file: rel)
            }
        }
        return out
    }

    private static func dotenvNote(_ file: String?) -> String {
        guard let file else { return "imported from project dotenv" }
        return "imported from \(file)"
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
