import CryptoKit
import Foundation
import Security

public enum LocalVaultRecovery {
    public static let fileName = "master-key.vvrecovery"
    private static let currentVersion = 1
    private static let kdf = "HKDF-SHA256"
    private static let info = Data("vibevault-local-recovery-v1".utf8)

    public static func protect(directory: URL, recoveryKey: String) throws {
        let vaultURL = directory.appendingPathComponent("secrets.vault")
        let vaultExists = FileManager.default.fileExists(atPath: vaultURL.path)
        let account = KeychainMasterKey.account(forVaultDirectory: directory)
        let key = try KeychainMasterKey.loadOrCreate(
            migratingFrom: directory.appendingPathComponent("master.key"),
            account: account,
            allowCreate: !vaultExists
        )
        let salt = try randomData(count: 32)
        let wrappingKey = try deriveKey(recoveryKey: recoveryKey, salt: salt)
        let masterKeyData = key.withUnsafeBytes { Data($0) }
        let sealed = try AES.GCM.seal(masterKeyData, using: wrappingKey)
        guard let combined = sealed.combined else {
            throw LocalVaultRecoveryError.corruptEnvelope
        }
        let envelope = Envelope(
            version: currentVersion,
            kdf: kdf,
            salt: salt,
            wrappedKey: combined
        )
        let url = directory.appendingPathComponent(fileName)
        try JSONEncoder().encode(envelope).write(to: url, options: .atomic)
        try FileManager.default.setAttributes(
            [.posixPermissions: 0o600], ofItemAtPath: url.path
        )
        VaultPaths.includeInBackup(directory)
        if vaultExists { VaultPaths.includeInBackup(vaultURL) }
        VaultPaths.includeInBackup(url)
        _ = try unwrap(envelope, recoveryKey: recoveryKey)
    }

    public static func restore(directory: URL, recoveryKey: String) throws {
        let vaultURL = directory.appendingPathComponent("secrets.vault")
        guard FileManager.default.fileExists(atPath: vaultURL.path) else {
            throw LocalVaultRecoveryError.vaultMissing
        }
        let envelopeURL = directory.appendingPathComponent(fileName)
        guard FileManager.default.fileExists(atPath: envelopeURL.path) else {
            throw LocalVaultRecoveryError.recoveryEnvelopeMissing
        }
        let envelope: Envelope
        do {
            envelope = try JSONDecoder().decode(Envelope.self, from: Data(contentsOf: envelopeURL))
        } catch {
            throw LocalVaultRecoveryError.corruptEnvelope
        }
        let candidate = try unwrap(envelope, recoveryKey: recoveryKey)
        do {
            _ = try VaultFileCrypto.open(Data(contentsOf: vaultURL), key: candidate)
        } catch {
            throw LocalVaultRecoveryError.authenticationFailed
        }
        let account = KeychainMasterKey.account(forVaultDirectory: directory)
        try KeychainMasterKey.install(candidate, account: account)
    }

    public static func isProtected(directory: URL) -> Bool {
        FileManager.default.fileExists(
            atPath: directory.appendingPathComponent(fileName).path
        )
    }

    private static func unwrap(_ envelope: Envelope, recoveryKey: String) throws -> SymmetricKey {
        guard envelope.version == currentVersion else {
            throw LocalVaultRecoveryError.unsupportedVersion(envelope.version)
        }
        guard envelope.kdf == kdf, envelope.salt.count == 32 else {
            throw LocalVaultRecoveryError.corruptEnvelope
        }
        do {
            let key = try deriveKey(recoveryKey: recoveryKey, salt: envelope.salt)
            let box = try AES.GCM.SealedBox(combined: envelope.wrappedKey)
            let data = try AES.GCM.open(box, using: key)
            guard data.count == 32 else { throw LocalVaultRecoveryError.corruptEnvelope }
            return SymmetricKey(data: data)
        } catch let error as LocalVaultRecoveryError {
            throw error
        } catch {
            throw LocalVaultRecoveryError.authenticationFailed
        }
    }

    private static func deriveKey(recoveryKey: String, salt: Data) throws -> SymmetricKey {
        let material = SymmetricKey(data: try CloudRecoveryKey.keyData(recoveryKey))
        return HKDF<SHA256>.deriveKey(
            inputKeyMaterial: material,
            salt: salt,
            info: info,
            outputByteCount: 32
        )
    }

    private static func randomData(count: Int) throws -> Data {
        var bytes = [UInt8](repeating: 0, count: count)
        guard SecRandomCopyBytes(kSecRandomDefault, count, &bytes) == errSecSuccess else {
            throw CloudSyncError.randomGenerationFailed
        }
        return Data(bytes)
    }

    private struct Envelope: Codable {
        let version: Int
        let kdf: String
        let salt: Data
        let wrappedKey: Data
    }
}
