import CryptoKit
import Foundation

/// AES-GCM helpers for the on-disk vault ciphertext.
enum VaultFileCrypto {
    static func seal(_ plaintext: Data, key: SymmetricKey) throws -> Data {
        let sealed = try AES.GCM.seal(plaintext, using: key)
        guard let combined = sealed.combined else {
            throw SecretError.vaultIO("seal failed")
        }
        return combined
    }

    static func open(_ blob: Data, key: SymmetricKey) throws -> Data {
        let box = try AES.GCM.SealedBox(combined: blob)
        return try AES.GCM.open(box, using: key)
    }

    static func loadOrCreateKey(legacyFileURL: URL, account: String) throws -> SymmetricKey {
        try KeychainMasterKey.loadOrCreate(migratingFrom: legacyFileURL, account: account)
    }
}
