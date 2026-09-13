import Foundation

/// Linux master key: Secret Service (libsecret) when a session keyring is
/// present, otherwise a mode-`0600` file. Existing file keys migrate on load.
enum LinuxMasterKeyStore {
    static func defaultClient() -> any LinuxSecretServiceClient {
        #if os(Linux)
        return LibSecretClient()
        #else
        return UnavailableSecretServiceClient()
        #endif
    }

    static func loadMasterKey(
        account: String,
        directory: URL,
        client: (any LinuxSecretServiceClient)? = nil
    ) throws -> SymmetricKey? {
        let client = client ?? defaultClient()
        if client.isAvailable, let data = try client.lookup(account: account) {
            guard data.count == 32 else { throw SecretError.vaultIO("corrupt libsecret master key") }
            FileSecureStore.deleteMasterKey(account: account, directory: directory)
            return SymmetricKey(data: data)
        }
        guard let fileKey = try FileSecureStore.loadMasterKey(account: account, directory: directory) else {
            return nil
        }
        if client.isAvailable {
            let data = fileKey.withUnsafeBytes { Data($0) }
            if (try? client.store(account: account, key: data)) != nil {
                FileSecureStore.deleteMasterKey(account: account, directory: directory)
            }
        }
        return fileKey
    }

    static func storeMasterKey(
        _ key: SymmetricKey,
        account: String,
        directory: URL,
        client: (any LinuxSecretServiceClient)? = nil
    ) throws {
        let data = key.withUnsafeBytes { Data($0) }
        guard data.count == 32 else { throw SecretError.vaultIO("master key must be 32 bytes") }
        let client = client ?? defaultClient()
        if client.isAvailable, (try? client.store(account: account, key: data)) != nil {
            FileSecureStore.deleteMasterKey(account: account, directory: directory)
            return
        }
        try FileSecureStore.storeMasterKey(key, account: account, directory: directory)
    }

    static func deleteMasterKey(
        account: String,
        directory: URL,
        client: (any LinuxSecretServiceClient)? = nil
    ) {
        let client = client ?? defaultClient()
        if client.isAvailable {
            try? client.delete(account: account)
        }
        FileSecureStore.deleteMasterKey(account: account, directory: directory)
    }

    static func masterKeyExists(
        account: String,
        directory: URL,
        client: (any LinuxSecretServiceClient)? = nil
    ) -> Bool {
        let client = client ?? defaultClient()
        if client.isAvailable, let data = try? client.lookup(account: account), data.count == 32 {
            return true
        }
        return FileSecureStore.masterKeyExists(account: account, directory: directory)
    }
}
