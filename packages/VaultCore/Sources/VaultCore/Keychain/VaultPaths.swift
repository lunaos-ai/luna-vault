import Foundation

enum VaultPaths {
    static func defaultDirectory() -> URL {
        if let override = ProcessInfo.processInfo.environment["VIBEVAULT_VAULT_DIR"]?
            .trimmingCharacters(in: .whitespacesAndNewlines),
           !override.isEmpty {
            return preparedDirectory(URL(fileURLWithPath: override).standardizedFileURL)
        }
        return preparedDirectory(platformDataRoot().appendingPathComponent("vibe-vault", isDirectory: true))
    }

    private static func platformDataRoot() -> URL {
        #if os(macOS)
        return FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory())
        #elseif os(Windows)
        if let appData = ProcessInfo.processInfo.environment["APPDATA"], !appData.isEmpty {
            return URL(fileURLWithPath: appData, isDirectory: true)
        }
        return FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("AppData/Roaming")
        #else
        if let xdg = ProcessInfo.processInfo.environment["XDG_DATA_HOME"], !xdg.isEmpty {
            return URL(fileURLWithPath: xdg, isDirectory: true)
        }
        return FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".local/share", isDirectory: true)
        #endif
    }

    private static func preparedDirectory(_ directory: URL) -> URL {
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        includeInBackup(directory)
        return directory
    }

    static func excludeFromBackup(_ url: URL) {
        #if os(macOS)
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        var mutable = url
        try? mutable.setResourceValues(values)
        #endif
    }

    static func includeInBackup(_ url: URL) {
        #if os(macOS)
        var values = URLResourceValues()
        values.isExcludedFromBackup = false
        var mutable = url
        try? mutable.setResourceValues(values)
        #endif
    }
}
