import CommonCrypto
import CryptoKit
import Foundation
import Security

public enum CloudSync {
    public static let fileName = "vault.vvsync"
    private static let legacyVersion = 1
    private static let version = 2
    private static let kdf = "pbkdf2-sha256+hkdf-sha256"
    private static let recoveryKdf = "hkdf-sha256"
    private static let cipher = "aes-256-gcm"
    private static let info = Data("vibevault-cloud-sync-v2".utf8)
    private static let legacyInfo = Data("vibevault-cloud-sync-v1".utf8)
    private static let recoveryInfo = Data("vibevault-cloud-recovery-v2".utf8)
    private static let kdfIterations = 600_000
    // Lower bound blocks downgrade to a fast KDF; upper bound blocks DoS via a hostile envelope.
    private static let kdfIterationRange = 600_000...10_000_000

    public static func iCloudDriveRootURL() -> URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Mobile Documents/com~apple~CloudDocs", isDirectory: true)
    }

    public static func isICloudDriveAvailable(
        at rootURL: URL = iCloudDriveRootURL(),
        fileManager: FileManager = .default
    ) -> Bool {
        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: rootURL.path, isDirectory: &isDirectory),
              isDirectory.boolValue else {
            return false
        }
        return fileManager.isWritableFile(atPath: rootURL.path)
    }

    public static func defaultICloudURL() -> URL {
        iCloudDriveRootURL()
            .appendingPathComponent("Documents")
            .appendingPathComponent("VibeVault/Sync", isDirectory: true)
            .appendingPathComponent(fileName)
    }

    public static func encrypt(
        _ snapshot: CloudSyncSnapshot,
        passphrase: String,
        recoveryKey: String? = nil
    ) throws -> Data {
        try validatePassphrase(passphrase)
        let salt = try secureRandomData(count: 32)
        let passphraseKey = try derivePassphraseKey(
            passphrase: passphrase,
            salt: salt,
            iterations: kdfIterations,
            info: info
        )
        let dataKeyBytes = try secureRandomData(count: 32)
        let dataKey = SymmetricKey(data: dataKeyBytes)
        let sealed = try AES.GCM.seal(try encoder.encode(snapshot), using: dataKey)
        let passphraseWrap = try AES.GCM.seal(dataKeyBytes, using: passphraseKey)

        var recoverySalt: Data?
        var recoveryWrap: AES.GCM.SealedBox?
        if let recoveryKey {
            let keyMaterial = try CloudRecoveryKey.keyData(recoveryKey)
            let generatedSalt = try secureRandomData(count: 32)
            recoverySalt = generatedSalt
            recoveryWrap = try AES.GCM.seal(
                dataKeyBytes,
                using: deriveRecoveryKey(keyMaterial: keyMaterial, salt: generatedSalt)
            )
        }

        let envelope = CloudSyncEnvelope(
            version: version,
            createdAt: Date(),
            sourceHost: snapshot.sourceHost,
            kdf: kdf,
            kdfIterations: kdfIterations,
            cipher: cipher,
            salt: salt.base64EncodedString(),
            nonce: encodedNonce(sealed),
            tag: sealed.tag.base64EncodedString(),
            ciphertext: sealed.ciphertext.base64EncodedString(),
            passphraseNonce: encodedNonce(passphraseWrap),
            passphraseTag: passphraseWrap.tag.base64EncodedString(),
            passphraseWrappedKey: passphraseWrap.ciphertext.base64EncodedString(),
            recoveryKdf: recoveryWrap == nil ? nil : recoveryKdf,
            recoverySalt: recoverySalt?.base64EncodedString(),
            recoveryNonce: recoveryWrap.map(encodedNonce),
            recoveryTag: recoveryWrap?.tag.base64EncodedString(),
            recoveryWrappedKey: recoveryWrap?.ciphertext.base64EncodedString()
        )
        return try encoder.encode(envelope)
    }

    public static func decrypt(_ data: Data, passphrase: String) throws -> CloudSyncSnapshot {
        let envelope = try decoder.decode(CloudSyncEnvelope.self, from: data)
        switch envelope.version {
        case legacyVersion:
            return try decryptLegacy(envelope, passphrase: passphrase)
        case version:
            let salt = try validatedPassphraseSalt(envelope)
            let wrappingKey = try derivePassphraseKey(
                passphrase: passphrase,
                salt: salt,
                iterations: envelope.kdfIterations,
                info: info
            )
            let dataKey = try unwrapDataKey(
                nonce: envelope.passphraseNonce,
                tag: envelope.passphraseTag,
                ciphertext: envelope.passphraseWrappedKey,
                using: wrappingKey
            )
            return try decryptSnapshot(envelope, dataKey: dataKey)
        default:
            throw CloudSyncError.unsupportedVersion(envelope.version)
        }
    }

    public static func decrypt(_ data: Data, recoveryKey: String) throws -> CloudSyncSnapshot {
        let envelope = try decoder.decode(CloudSyncEnvelope.self, from: data)
        guard envelope.version == version else { throw CloudSyncError.recoveryUnavailable }
        guard envelope.recoveryKdf == recoveryKdf,
              let saltValue = envelope.recoverySalt,
              let salt = Data(base64Encoded: saltValue),
              envelope.recoveryNonce != nil,
              envelope.recoveryTag != nil,
              envelope.recoveryWrappedKey != nil else {
            throw CloudSyncError.recoveryUnavailable
        }
        let keyMaterial = try CloudRecoveryKey.keyData(recoveryKey)
        let dataKey = try unwrapDataKey(
            nonce: envelope.recoveryNonce,
            tag: envelope.recoveryTag,
            ciphertext: envelope.recoveryWrappedKey,
            using: deriveRecoveryKey(keyMaterial: keyMaterial, salt: salt)
        )
        return try decryptSnapshot(envelope, dataKey: dataKey)
    }

    public static func write(_ data: Data, to url: URL) throws {
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try data.write(to: url, options: .atomic)
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
    }

    private static func decryptLegacy(
        _ envelope: CloudSyncEnvelope,
        passphrase: String
    ) throws -> CloudSyncSnapshot {
        guard envelope.kdf == kdf,
              envelope.cipher == cipher,
              kdfIterationRange.contains(envelope.kdfIterations),
              let salt = Data(base64Encoded: envelope.salt) else {
            throw CloudSyncError.corruptEnvelope
        }
        let key = try derivePassphraseKey(
            passphrase: passphrase,
            salt: salt,
            iterations: envelope.kdfIterations,
            info: legacyInfo
        )
        return try decryptSnapshot(envelope, dataKey: key)
    }

    private static func validatedPassphraseSalt(_ envelope: CloudSyncEnvelope) throws -> Data {
        guard envelope.kdf == kdf,
              envelope.cipher == cipher,
              kdfIterationRange.contains(envelope.kdfIterations),
              let salt = Data(base64Encoded: envelope.salt),
              envelope.passphraseNonce != nil,
              envelope.passphraseTag != nil,
              envelope.passphraseWrappedKey != nil else {
            throw CloudSyncError.corruptEnvelope
        }
        return salt
    }

    private static func decryptSnapshot(
        _ envelope: CloudSyncEnvelope,
        dataKey: SymmetricKey
    ) throws -> CloudSyncSnapshot {
        guard envelope.cipher == cipher,
              let nonceData = Data(base64Encoded: envelope.nonce),
              let tag = Data(base64Encoded: envelope.tag),
              let ciphertext = Data(base64Encoded: envelope.ciphertext) else {
            throw CloudSyncError.corruptEnvelope
        }
        do {
            let nonce = try AES.GCM.Nonce(data: nonceData)
            let box = try AES.GCM.SealedBox(nonce: nonce, ciphertext: ciphertext, tag: tag)
            let plain = try AES.GCM.open(box, using: dataKey)
            let snapshot = try decoder.decode(CloudSyncSnapshot.self, from: plain)
            guard (legacyVersion...3).contains(snapshot.version) else {
                throw CloudSyncError.unsupportedVersion(snapshot.version)
            }
            return snapshot
        } catch let error as CloudSyncError {
            throw error
        } catch {
            throw CloudSyncError.authenticationFailed
        }
    }

    private static func unwrapDataKey(
        nonce: String?,
        tag: String?,
        ciphertext: String?,
        using wrappingKey: SymmetricKey
    ) throws -> SymmetricKey {
        guard let nonce,
              let tag,
              let ciphertext,
              let nonceData = Data(base64Encoded: nonce),
              let tagData = Data(base64Encoded: tag),
              let ciphertextData = Data(base64Encoded: ciphertext) else {
            throw CloudSyncError.corruptEnvelope
        }
        do {
            let box = try AES.GCM.SealedBox(
                nonce: AES.GCM.Nonce(data: nonceData),
                ciphertext: ciphertextData,
                tag: tagData
            )
            let bytes = try AES.GCM.open(box, using: wrappingKey)
            guard bytes.count == 32 else { throw CloudSyncError.corruptEnvelope }
            return SymmetricKey(data: bytes)
        } catch let error as CloudSyncError {
            throw error
        } catch {
            throw CloudSyncError.authenticationFailed
        }
    }

    private static func validatePassphrase(_ passphrase: String) throws {
        guard passphrase.count >= 12 else { throw CloudSyncError.weakPassphrase }
    }

    private static func derivePassphraseKey(
        passphrase: String,
        salt: Data,
        iterations: Int,
        info: Data
    ) throws -> SymmetricKey {
        var stretched = Data(count: 32)
        let passphraseLength = passphrase.utf8.count
        let status = stretched.withUnsafeMutableBytes { stretchedBytes in
            salt.withUnsafeBytes { saltBytes in
                CCKeyDerivationPBKDF(
                    CCPBKDFAlgorithm(kCCPBKDF2),
                    passphrase, passphraseLength,
                    saltBytes.bindMemory(to: UInt8.self).baseAddress, salt.count,
                    CCPseudoRandomAlgorithm(kCCPRFHmacAlgSHA256),
                    UInt32(iterations),
                    stretchedBytes.bindMemory(to: UInt8.self).baseAddress, 32
                )
            }
        }
        guard status == kCCSuccess else { throw CloudSyncError.keyDerivationFailed }
        return HKDF<SHA256>.deriveKey(
            inputKeyMaterial: SymmetricKey(data: stretched),
            salt: salt,
            info: info,
            outputByteCount: 32
        )
    }

    private static func deriveRecoveryKey(keyMaterial: Data, salt: Data) -> SymmetricKey {
        HKDF<SHA256>.deriveKey(
            inputKeyMaterial: SymmetricKey(data: keyMaterial),
            salt: salt,
            info: recoveryInfo,
            outputByteCount: 32
        )
    }

    private static func encodedNonce(_ box: AES.GCM.SealedBox) -> String {
        box.nonce.withUnsafeBytes { Data($0).base64EncodedString() }
    }

    private static func secureRandomData(count: Int) throws -> Data {
        var bytes = [UInt8](repeating: 0, count: count)
        guard SecRandomCopyBytes(kSecRandomDefault, count, &bytes) == errSecSuccess else {
            throw CloudSyncError.randomGenerationFailed
        }
        return Data(bytes)
    }

    private static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        return encoder
    }()

    private static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()
}
