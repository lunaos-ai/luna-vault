import Foundation

public struct CloudBackupFile: Equatable, Identifiable, Sendable {
    public var id: String { url.path }
    public let url: URL
    public let createdAt: Date
    public let size: Int64

    public init(url: URL, createdAt: Date, size: Int64) {
        self.url = url
        self.createdAt = createdAt
        self.size = size
    }
}

public struct CloudBackupWriteResult: Equatable, Sendable {
    public let backup: CloudBackupFile
    public let removed: [CloudBackupFile]

    public init(backup: CloudBackupFile, removed: [CloudBackupFile]) {
        self.backup = backup
        self.removed = removed
    }
}

public enum CloudBackupArchive {
    public static let filePrefix = "vault-"
    public static let fileExtension = "vvsync"

    public static func defaultICloudDirectory() -> URL {
        CloudSync.defaultICloudURL()
            .deletingLastPathComponent()
            .appendingPathComponent("Backups", isDirectory: true)
    }

    public static func backupURL(
        in directory: URL = defaultICloudDirectory(),
        at date: Date = Date(),
        identifier: String = UUID().uuidString
    ) -> URL {
        let timestamp = formattedTimestamp(date)
        let suffix = identifier
            .lowercased()
            .filter { $0.isLetter || $0.isNumber || $0 == "-" }
        return directory.appendingPathComponent(
            "\(filePrefix)\(timestamp)-\(suffix).\(fileExtension)"
        )
    }

    public static func write(
        _ data: Data,
        to directory: URL = defaultICloudDirectory(),
        at date: Date = Date(),
        identifier: String = UUID().uuidString,
        retentionCount: Int
    ) throws -> CloudBackupWriteResult {
        let url = backupURL(in: directory, at: date, identifier: identifier)
        try CloudSync.write(data, to: url)
        try FileManager.default.setAttributes(
            [.modificationDate: date],
            ofItemAtPath: url.path
        )
        let removed = try prune(in: directory, keeping: retentionCount)
        let backup = try file(at: url)
        return CloudBackupWriteResult(backup: backup, removed: removed)
    }

    public static func list(
        in directory: URL = defaultICloudDirectory()
    ) throws -> [CloudBackupFile] {
        let manager = FileManager.default
        guard manager.fileExists(atPath: directory.path) else { return [] }
        let urls = try manager.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.contentModificationDateKey, .fileSizeKey, .isRegularFileKey],
            options: [.skipsHiddenFiles]
        )
        return try urls
            .filter(isManagedBackup)
            .map(file(at:))
            .sorted { lhs, rhs in
                if lhs.createdAt == rhs.createdAt {
                    return lhs.url.lastPathComponent > rhs.url.lastPathComponent
                }
                return lhs.createdAt > rhs.createdAt
            }
    }

    @discardableResult
    public static func prune(
        in directory: URL = defaultICloudDirectory(),
        keeping retentionCount: Int
    ) throws -> [CloudBackupFile] {
        let backups = try list(in: directory)
        let keep = max(1, retentionCount)
        let removed = Array(backups.dropFirst(keep))
        for backup in removed {
            try FileManager.default.removeItem(at: backup.url)
        }
        return removed
    }

    private static func isManagedBackup(_ url: URL) -> Bool {
        url.pathExtension.lowercased() == fileExtension
            && url.deletingPathExtension().lastPathComponent.hasPrefix(filePrefix)
    }

    private static func file(at url: URL) throws -> CloudBackupFile {
        let values = try url.resourceValues(forKeys: [
            .contentModificationDateKey,
            .fileSizeKey,
            .isRegularFileKey
        ])
        guard values.isRegularFile == true else {
            throw CocoaError(.fileReadUnsupportedScheme)
        }
        return CloudBackupFile(
            url: url,
            createdAt: values.contentModificationDate ?? .distantPast,
            size: Int64(values.fileSize ?? 0)
        )
    }

    private static func formattedTimestamp(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        return formatter.string(from: date)
    }
}

public enum CloudBackupSchedule {
    public static func isDue(
        lastBackupAt: Date?,
        intervalHours: Int,
        now: Date = Date()
    ) -> Bool {
        guard let lastBackupAt else { return true }
        let interval = TimeInterval(max(1, intervalHours) * 60 * 60)
        return now.timeIntervalSince(lastBackupAt) >= interval
    }
}
