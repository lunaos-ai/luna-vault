import Foundation

enum VaultPaths {
    static func defaultDirectory() -> URL {
        if let override = ProcessInfo.processInfo.environment["VIBEVAULT_VAULT_DIR"]?.trimmingCharacters(in: .whitespacesAndNewlines),
           !override.isEmpty {
            return preparedDirectory(URL(fileURLWithPath: override).standardizedFileURL)
        }

        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory())
        return preparedDirectory(base.appendingPathComponent("vibe-vault", isDirectory: true))
    }

    private static func preparedDirectory(_ directory: URL) -> URL {
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        excludeFromBackup(directory)
        return directory
    }

    static func excludeFromBackup(_ url: URL) {
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        var mutable = url
        try? mutable.setResourceValues(values)
    }
}
