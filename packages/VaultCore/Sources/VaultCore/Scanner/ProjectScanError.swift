import Foundation

public enum ProjectScanError: Error, Equatable, LocalizedError, Sendable {
    case notFound(String)
    case notDirectory(String)

    public var errorDescription: String? {
        switch self {
        case .notFound(let path):
            return "project folder not found: \(path)"
        case .notDirectory(let path):
            return "not a folder: \(path)"
        }
    }
}

extension ProjectScanner {
    public static func validateRoot(_ url: URL) throws {
        let root = url.standardizedFileURL
        guard FileManager.default.fileExists(atPath: root.path) else {
            throw ProjectScanError.notFound(root.path)
        }
        let isDirectory = (try? root.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
        guard isDirectory else {
            throw ProjectScanError.notDirectory(root.path)
        }
    }
}
