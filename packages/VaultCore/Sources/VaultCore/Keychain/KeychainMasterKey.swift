import CryptoKit
import Foundation
import Security

/// AES master key for the on-disk vault — stored in Keychain, not beside the ciphertext.
enum KeychainMasterKey {
    static let service = "dev.vibevault"
    static let defaultAccount = "vault.master"
    private static let cacheQueue = DispatchQueue(label: "dev.vibevault.master-key-cache")
    private static var cache: [String: SymmetricKey] = [:]

    static func loadOrCreate(
        migratingFrom legacyFile: URL?,
        account: String = defaultAccount,
        allowCreate: Bool = true
    ) throws -> SymmetricKey {
        if let cached = cacheQueue.sync(execute: { cache[account] }) {
            return cached
        }
        let key: SymmetricKey
        if let existing = try read(account: account) {
            key = existing
        } else if let legacyFile, let migrated = try migrateFile(legacyFile, account: account) {
            key = migrated
        } else if !allowCreate {
            throw LocalVaultRecoveryError.masterKeyUnavailable
        } else {
            key = try create(account: account)
        }
        cacheQueue.sync { cache[account] = key }
        return key
    }

    static func account(forVaultDirectory directory: URL) -> String {
        let leaf = directory.standardizedFileURL.lastPathComponent
        return leaf == "vibe-vault" ? defaultAccount : "vault.master.\(leaf)"
    }

    static func exists(account: String) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        return SecItemCopyMatching(query as CFDictionary, nil) == errSecSuccess
    }

    static func install(_ key: SymmetricKey, account: String) throws {
        let data = key.withUnsafeBytes { Data($0) }
        guard data.count == 32 else { throw LocalVaultRecoveryError.corruptEnvelope }
        try store(data, account: account)
        cacheQueue.sync { cache[account] = key }
    }

    private static func read(account: String) throws -> SymmetricKey? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess else { throw SecretError.keychainStatus(status) }
        guard let data = item as? Data, data.count == 32 else {
            throw LocalVaultRecoveryError.masterKeyUnavailable
        }
        return SymmetricKey(data: data)
    }

    private static func create(account: String) throws -> SymmetricKey {
        var bytes = [UInt8](repeating: 0, count: 32)
        let status = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        guard status == errSecSuccess else { throw SecretError.vaultIO("keygen failed") }
        let data = Data(bytes)
        try store(data, account: account)
        return SymmetricKey(data: data)
    }

    private static func migrateFile(_ url: URL, account: String) throws -> SymmetricKey? {
        let fm = FileManager.default
        guard fm.fileExists(atPath: url.path) else { return nil }
        let data = try Data(contentsOf: url)
        guard data.count == 32 else { throw SecretError.vaultIO("bad master key file") }
        try store(data, account: account)
        try? fm.removeItem(at: url)
        return SymmetricKey(data: data)
    }

    private static func store(_ data: Data, account: String) throws {
        let del: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        let attributes: [String: Any] = [
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]
        let updateStatus = SecItemUpdate(del as CFDictionary, attributes as CFDictionary)
        if updateStatus == errSecSuccess { return }
        guard updateStatus == errSecItemNotFound else {
            throw SecretError.keychainStatus(updateStatus)
        }
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ].merging(attributes) { _, new in new }
        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else { throw SecretError.keychainStatus(status) }
    }

    /// Test helper: remove Keychain item for a vault account.
    static func deleteForTests(account: String) {
        _ = cacheQueue.sync { cache.removeValue(forKey: account) }
        let del: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(del as CFDictionary)
    }
}
