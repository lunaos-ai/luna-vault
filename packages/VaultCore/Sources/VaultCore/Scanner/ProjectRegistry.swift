import Foundation

public struct ProjectRegistryDocument: Codable, Equatable, Sendable {
    public var version: Int
    public var selectedID: UUID?
    public var projects: [ProjectRecord]

    public init(version: Int = 1, selectedID: UUID? = nil, projects: [ProjectRecord] = []) {
        self.version = version
        self.selectedID = selectedID
        self.projects = projects
    }
}

public final class ProjectRegistry: @unchecked Sendable {
    private let fileURL: URL
    private let fileManager: FileManager
    private var document: ProjectRegistryDocument

    public init(directory: URL? = nil, fileManager: FileManager = .default) {
        let dir = directory ?? VaultPaths.defaultDirectory()
        self.fileURL = dir.appendingPathComponent("projects.json")
        self.fileManager = fileManager
        self.document = Self.load(from: fileURL) ?? ProjectRegistryDocument()
    }

    public var selectedID: UUID? { document.selectedID }

    public func list() -> [ProjectRecord] {
        document.projects.sorted {
            ($0.lastScannedAt ?? .distantPast) > ($1.lastScannedAt ?? .distantPast)
        }
    }

    public func selected() -> ProjectRecord? {
        guard let id = document.selectedID else { return list().first }
        return document.projects.first { $0.id == id } ?? list().first
    }

    @discardableResult
    public func upsert(url: URL, prefix: String? = nil) throws -> ProjectRecord {
        let root = url.standardizedFileURL
        if let idx = document.projects.firstIndex(where: { $0.path == root.path }) {
            if let prefix, !prefix.isEmpty { document.projects[idx].prefix = prefix }
            document.projects[idx].name = root.lastPathComponent
            document.selectedID = document.projects[idx].id
            try save()
            return document.projects[idx]
        }
        let record = ProjectRecord.make(url: root, prefix: prefix)
        document.projects.append(record)
        document.selectedID = record.id
        try save()
        return record
    }

    public func select(id: UUID?) throws {
        document.selectedID = id
        try save()
    }

    public func remove(id: UUID) throws {
        document.projects.removeAll { $0.id == id }
        if document.selectedID == id { document.selectedID = document.projects.first?.id }
        try save()
    }

    public func relocate(id: UUID, to url: URL) throws -> ProjectRecord {
        guard let idx = document.projects.firstIndex(where: { $0.id == id }) else {
            throw ProjectScanError.notFound(url.path)
        }
        let root = url.standardizedFileURL
        document.projects[idx].path = root.path
        document.projects[idx].name = root.lastPathComponent
        document.projects[idx].bookmark = ProjectRecord.bookmarkData(for: root)
        document.selectedID = id
        try save()
        return document.projects[idx]
    }

    public func recordScan(id: UUID, result: ScanResult, url: URL? = nil) throws {
        guard let idx = document.projects.firstIndex(where: { $0.id == id }) else { return }
        document.projects[idx].lastScannedAt = Date()
        document.projects[idx].requiredCount = result.required.count
        document.projects[idx].missingCount = result.missing.count
        document.projects[idx].extraCount = result.extra.count
        document.projects[idx].leakCount = result.gitLeaks.count
        if let url {
            document.projects[idx].path = url.standardizedFileURL.path
            document.projects[idx].bookmark = ProjectRecord.bookmarkData(for: url)
        }
        try save()
    }

    public func migratePrefixPaths(_ prefixes: [String: String]) throws {
        for (path, prefix) in prefixes where !path.isEmpty {
            let url = URL(fileURLWithPath: path, isDirectory: true)
            guard fileManager.fileExists(atPath: url.path) else { continue }
            _ = try upsert(url: url, prefix: prefix.isEmpty ? nil : prefix)
        }
    }

    private func save() throws {
        let dir = fileURL.deletingLastPathComponent()
        try fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(document)
        try data.write(to: fileURL, options: .atomic)
        PlatformFilePermissions.restrictToOwner(fileURL)
    }

    private static func load(from url: URL) -> ProjectRegistryDocument? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(ProjectRegistryDocument.self, from: data)
    }
}
