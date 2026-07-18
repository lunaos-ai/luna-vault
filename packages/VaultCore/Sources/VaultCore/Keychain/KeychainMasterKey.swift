import CryptoKit
import Foundation
import Security

/// AES master key for the on-disk vault — stored in Keychain, not beside the ciphertext.
enum KeychainMasterKey {
    static let service = "dev.vibevault"
    static let defaultAccount = "vault.master"

    static func loadOrCreate(
        migratingFrom legacyFile: URL?,
        account: String = defaultAccount
    ) throws -> SymmetricKey {
        if let existing = try read(account: account) { return existing }
        if let legacyFile, let migrated = try migrateFile(legacyFile, account: account) {
            return migrated
        }
        return try create(account: account)
    }

    private static func read(account: String) throws -> SymmetricKey? {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess, let data = item as? Data, data.count == 32 else {
            throw SecretError.vaultIO("bad master key in Keychain")
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
        SecItemDelete(del as CFDictionary)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]
        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else { throw SecretError.keychainStatus(status) }
    }

    /// Test helper: remove Keychain item for a vault account.
    static func deleteForTests(account: String) {
        let del: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(del as CFDictionary)
    }
}
