import Foundation

/// Finds and merges dotenv files under a project tree.
public enum DotenvDiscovery {
    /// Lowest → highest priority; later entries override earlier ones.
    public static let filenames: [String] = [
        ".env",
        ".env.development",
        ".env.production",
        ".env.test",
        ".env.local",
        ".env.development.local",
        ".env.production.local",
        ".env.test.local"
    ]

    private static let skipDirs: Set<String> = [
        "node_modules", ".git", ".build", "DerivedData", "build", "dist", ".next", ".vercel"
    ]
    private static let maxDepth = 8

    public static func findFiles(
        under root: URL,
        fileManager: FileManager = .default
    ) -> [URL] {
        let wanted = Set(filenames)
        var found: [URL] = []
        let enumerator = fileManager.enumerator(
            at: root,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsPackageDescendants]
        )
        let rootDepth = root.pathComponents.count
        while let url = enumerator?.nextObject() as? URL {
            let last = url.lastPathComponent
            if skipDirs.contains(last) {
                enumerator?.skipDescendants()
                continue
            }
            if url.pathComponents.count - rootDepth > maxDepth {
                enumerator?.skipDescendants()
                continue
            }
            if wanted.contains(last) { found.append(url) }
        }
        return found.sorted(by: mergeOrder(root: root))
    }

    public static func loadValues(from files: [URL]) -> [String: String] {
        var values: [String: String] = [:]
        for url in files {
            guard let content = try? String(contentsOf: url, encoding: .utf8) else { continue }
            for item in DotenvImporter.parse(content) {
                values[item.name] = item.value
            }
        }
        return values
    }

    public static func loadValues(under root: URL, fileManager: FileManager = .default) -> [String: String] {
        loadValues(from: findFiles(under: root, fileManager: fileManager))
    }

    private static func mergeOrder(root: URL) -> (URL, URL) -> Bool {
        let rank = Dictionary(uniqueKeysWithValues: filenames.enumerated().map { ($1, $0) })
        return { a, b in
            let depthA = a.pathComponents.count - root.pathComponents.count
            let depthB = b.pathComponents.count - root.pathComponents.count
            if depthA != depthB { return depthA < depthB }
            return (rank[a.lastPathComponent] ?? 0) < (rank[b.lastPathComponent] ?? 0)
        }
    }
}
