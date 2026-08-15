import CommonCrypto
import CryptoKit
import Foundation
import Security

extension CloudSync {
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

    static func decryptLegacy(
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

    static func validatedPassphraseSalt(_ envelope: CloudSyncEnvelope) throws -> Data {
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

    static func decryptSnapshot(
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

    static func unwrapDataKey(
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
}
