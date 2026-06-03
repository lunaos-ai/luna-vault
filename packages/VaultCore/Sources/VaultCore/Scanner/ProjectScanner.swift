import Foundation

public struct ScanResult: Equatable, Sendable {
    public let required: Set<String>
    public let missing: Set<String>
    public let extra: Set<String>
    public let sources: [String: [String]]  // filename -> secret names found

    public init(required: Set<String>, missing: Set<String>, extra: Set<String>, sources: [String: [String]]) {
        self.required = required
        self.missing = missing
        self.extra = extra
        self.sources = sources
    }
}

public protocol SecretFileParser: Sendable {
    var filename: String { get }
    func parse(content: String) -> [String]
}

public protocol ProjectScanning: Sendable {
    func scan(projectURL: URL, knownSecrets: Set<String>) throws -> ScanResult
}

public final class ProjectScanner: ProjectScanning, @unchecked Sendable {
    private let parsers: [SecretFileParser]
    private let fileManager: FileManager

    public init(
        parsers: [SecretFileParser] = ProjectScanner.defaultParsers(),
        fileManager: FileManager = .default
    ) {
        self.parsers = parsers
        self.fileManager = fileManager
    }

    public static func defaultParsers() -> [SecretFileParser] {
        [
            WranglerParser(),
            VercelParser(),
            DotenvExampleParser(),
            PackageJsonParser(),
            NextConfigParser()
        ]
    }

    public func scan(projectURL: URL, knownSecrets: Set<String>) throws -> ScanResult {
        var sources: [String: [String]] = [:]
        var required = Set<String>()
        let wanted = Set(parsers.map(\.filename))
        let filesByName = findFiles(matching: wanted, under: projectURL)
        for parser in parsers {
            for fileURL in filesByName[parser.filename] ?? [] {
                guard let content = try? String(contentsOf: fileURL, encoding: .utf8) else { continue }
                let names = parser.parse(content: content).filter { isLikelySecret($0) }
                if names.isEmpty { continue }
                let key = fileURL.path.replacingOccurrences(of: projectURL.path + "/", with: "")
                sources[key, default: []].append(contentsOf: names)
                required.formUnion(names)
            }
        }
        let missing = required.subtracting(knownSecrets)
        let extra = knownSecrets.subtracting(required)
        return ScanResult(required: required, missing: missing, extra: extra, sources: sources)
    }

    private static let skipDirs: Set<String> = [
        "node_modules", ".git", ".build", "DerivedData", "build", "dist", ".next", ".vercel"
    ]
    private static let maxDepth = 8

    private func findFiles(matching names: Set<String>, under root: URL) -> [String: [URL]] {
        var results: [String: [URL]] = [:]
        let enumerator = fileManager.enumerator(
            at: root,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsPackageDescendants]
        )
        let rootDepth = root.pathComponents.count
        while let url = enumerator?.nextObject() as? URL {
            let last = url.lastPathComponent
            if Self.skipDirs.contains(last) {
                enumerator?.skipDescendants()
                continue
            }
            if url.pathComponents.count - rootDepth > Self.maxDepth {
                enumerator?.skipDescendants()
                continue
            }
            if names.contains(last) {
                results[last, default: []].append(url)
            }
        }
        return results
    }

    private func isLikelySecret(_ name: String) -> Bool {
        let upper = name.uppercased()
        if name != upper && !name.contains("_") { return false }
        let banned: Set<String> = ["NODE_ENV", "PATH", "HOME", "USER", "SHELL", "PWD", "LANG", "TERM"]
        if banned.contains(upper) { return false }
        guard name.count >= 3, name.count <= 128 else { return false }
        let valid = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "_"))
        return name.unicodeScalars.allSatisfy { valid.contains($0) }
    }
}
