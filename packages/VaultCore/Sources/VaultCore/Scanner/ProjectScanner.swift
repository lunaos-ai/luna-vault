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
        for parser in parsers {
            let candidates = findFiles(matching: parser.filename, under: projectURL)
            for fileURL in candidates {
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

    private func findFiles(matching name: String, under root: URL) -> [URL] {
        var results: [URL] = []
        let enumerator = fileManager.enumerator(
            at: root,
            includingPropertiesForKeys: nil,
            options: [.skipsPackageDescendants]
        )
        let skipDirs: Set<String> = ["node_modules", ".git", ".build", "DerivedData", "build", "dist", ".next", ".vercel"]
        while let url = enumerator?.nextObject() as? URL {
            let last = url.lastPathComponent
            if skipDirs.contains(last) {
                enumerator?.skipDescendants()
                continue
            }
            if last == name { results.append(url) }
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
