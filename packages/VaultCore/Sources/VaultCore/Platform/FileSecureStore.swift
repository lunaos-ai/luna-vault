import Foundation

/// Master-key and prefs storage for Linux/Windows when Keychain/DPAPI are unavailable.
/// Files are mode `0600` under the vault data directory. Prefer OS keyrings in a later release.
enum FileSecureStore {
    private static let masterPrefix = "master."
    private static let prefsFileName = "prefs.json"

    static func masterKeyURL(account: String, directory: URL) -> URL {
        let safe = account.replacingOccurrences(of: "/", with: "_")
        return directory.appendingPathComponent("\(masterPrefix)\(safe).key")
    }

    static func loadMasterKey(account: String, directory: URL) throws -> SymmetricKey? {
        let url = masterKeyURL(account: account, directory: directory)
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        let data = try Data(contentsOf: url)
        guard data.count == 32 else { throw SecretError.vaultIO("corrupt master key file") }
        return SymmetricKey(data: data)
    }

    static func storeMasterKey(_ key: SymmetricKey, account: String, directory: URL) throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = masterKeyURL(account: account, directory: directory)
        let data = key.withUnsafeBytes { Data($0) }
        try data.write(to: url, options: .atomic)
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
        VaultPaths.excludeFromBackup(url)
    }

    static func deleteMasterKey(account: String, directory: URL) {
        let url = masterKeyURL(account: account, directory: directory)
        try? FileManager.default.removeItem(at: url)
    }

    static func masterKeyExists(account: String, directory: URL) -> Bool {
        FileManager.default.fileExists(atPath: masterKeyURL(account: account, directory: directory).path)
    }

    static func prefsURL(directory: URL) -> URL {
        directory.appendingPathComponent(prefsFileName)
    }

    static func loadPrefs(directory: URL) -> [String: Data] {
        let url = prefsURL(directory: directory)
        guard let data = try? Data(contentsOf: url),
              let decoded = try? JSONDecoder().decode([String: Data].self, from: data) else {
            return [:]
        }
        return decoded
    }

    static func savePrefs(_ values: [String: Data], directory: URL) throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = prefsURL(directory: directory)
        let data = try JSONEncoder().encode(values)
        try data.write(to: url, options: .atomic)
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
        VaultPaths.excludeFromBackup(url)
    }
}
