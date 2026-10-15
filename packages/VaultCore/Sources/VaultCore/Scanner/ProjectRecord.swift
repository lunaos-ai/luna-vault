import Foundation

public enum ProjectAccess: String, Sendable, Equatable {
    case ready
    case missing
    case notDirectory
}

public struct ProjectRecord: Codable, Equatable, Identifiable, Sendable {
    public var id: UUID
    public var path: String
    public var name: String
    public var prefix: String
    public var lastScannedAt: Date?
    public var requiredCount: Int
    public var missingCount: Int
    public var extraCount: Int
    public var leakCount: Int
    public var bookmark: Data?

    public init(
        id: UUID = UUID(),
        path: String,
        name: String,
        prefix: String,
        lastScannedAt: Date? = nil,
        requiredCount: Int = 0,
        missingCount: Int = 0,
        extraCount: Int = 0,
        leakCount: Int = 0,
        bookmark: Data? = nil
    ) {
        self.id = id
        self.path = path
        self.name = name
        self.prefix = prefix
        self.lastScannedAt = lastScannedAt
        self.requiredCount = requiredCount
        self.missingCount = missingCount
        self.extraCount = extraCount
        self.leakCount = leakCount
        self.bookmark = bookmark
    }

    public var url: URL { URL(fileURLWithPath: path, isDirectory: true) }

    public var access: ProjectAccess {
        let resolved = resolvedURL()
        guard FileManager.default.fileExists(atPath: resolved.path) else { return .missing }
        let isDir = (try? resolved.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
        return isDir ? .ready : .notDirectory
    }

    public func resolvedURL() -> URL {
        #if os(macOS)
        if let bookmark {
            var stale = false
            if let url = try? URL(
                resolvingBookmarkData: bookmark,
                options: [.withoutUI],
                relativeTo: nil,
                bookmarkDataIsStale: &stale
            ) {
                return url.standardizedFileURL
            }
        }
        #endif
        return url.standardizedFileURL
    }

    public static func make(url: URL, prefix: String? = nil) -> ProjectRecord {
        let root = url.standardizedFileURL
        let name = root.lastPathComponent
        let pref = prefix?.isEmpty == false ? prefix! : SecretNaming.defaultProjectPrefix(from: root)
        return ProjectRecord(path: root.path, name: name, prefix: pref, bookmark: bookmarkData(for: root))
    }

    static func bookmarkData(for url: URL) -> Data? {
        #if os(macOS)
        return try? url.bookmarkData(options: .minimalBookmark, includingResourceValuesForKeys: nil, relativeTo: nil)
        #else
        return nil
        #endif
    }
}
