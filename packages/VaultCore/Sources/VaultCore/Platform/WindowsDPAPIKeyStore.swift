#if os(Windows)
import Foundation

/// Placeholder for Windows Credential Manager / DPAPI master-key storage.
/// Builds on Windows still use `FileSecureStore` until this backend is wired.
/// Tracked as `PlatformSupport.MasterKeyBackend.windowsDPAPI`.
enum WindowsDPAPIKeyStore {
    static var isImplemented: Bool { false }

    static func loadMasterKey(account: String) throws -> SymmetricKey? {
        _ = account
        throw SecretError.vaultIO("Windows DPAPI master-key storage is not implemented yet; using FileSecureStore")
    }

    static func storeMasterKey(_ key: SymmetricKey, account: String) throws {
        _ = (key, account)
        throw SecretError.vaultIO("Windows DPAPI master-key storage is not implemented yet; using FileSecureStore")
    }
}
#endif
