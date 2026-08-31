import Foundation

extension CloudSync {
    public static func decrypt(_ data: Data, recoveryKey: String) throws -> CloudSyncSnapshot {
        let enteredID = try CloudRecoveryKey.identifier(recoveryKey)
        let enteredFingerprint = CloudRecoveryKey.fingerprint(identifier: enteredID)
        let envelope = try decoder.decode(CloudSyncEnvelope.self, from: data)
        try validateRecoveryEnvelope(envelope)
        if let storedID = envelope.recoveryKeyID, storedID != enteredID {
            throw CloudSyncError.recoveryKeyMismatch(
                expectedFingerprint: CloudRecoveryKey.fingerprint(identifier: storedID),
                enteredFingerprint: enteredFingerprint
            )
        }
        let dataKey: SymmetricKey
        do {
            dataKey = try unwrapRecoveryWrapping(envelope, recoveryKey: recoveryKey)
        } catch CloudSyncError.authenticationFailed {
            if envelope.recoveryKeyID == enteredID {
                throw CloudSyncError.bundleCorrupt
            }
            throw CloudSyncError.recoveryKeyMismatch(
                expectedFingerprint: envelope.recoveryKeyID.map(CloudRecoveryKey.fingerprint(identifier:)),
                enteredFingerprint: enteredFingerprint
            )
        }
        do {
            return try decryptSnapshot(envelope, dataKey: dataKey)
        } catch CloudSyncError.authenticationFailed {
            throw CloudSyncError.bundleCorrupt
        }
    }

    public static func decrypt(_ data: Data, keyring: RecoveryKeyring) throws -> CloudSyncSnapshot {
        let info = try inspect(data)
        guard info.hasRecoveryProtection else { throw CloudSyncError.recoveryUnavailable }
        if let identifier = info.recoveryKeyID {
            guard let record = keyring.record(identifier: identifier) else {
                throw CloudSyncError.recoveryKeyNotInstalled(
                    fingerprint: CloudRecoveryKey.fingerprint(identifier: identifier)
                )
            }
            return try decrypt(data, recoveryKey: record.canonicalKey)
        }
        for record in keyring.records {
            do {
                return try decrypt(data, recoveryKey: record.canonicalKey)
            } catch CloudSyncError.recoveryKeyMismatch {
                continue
            }
        }
        throw CloudSyncError.recoveryKeyRequired
    }

    static func validateRecoveryEnvelope(_ envelope: CloudSyncEnvelope) throws {
        guard envelope.version == version else { throw CloudSyncError.recoveryUnavailable }
        guard envelope.recoveryKdf == recoveryKdf,
              envelope.recoverySalt != nil,
              envelope.recoveryNonce != nil,
              envelope.recoveryTag != nil,
              envelope.recoveryWrappedKey != nil else {
            throw CloudSyncError.recoveryUnavailable
        }
    }

    static func unwrapRecoveryWrapping(
        _ envelope: CloudSyncEnvelope,
        recoveryKey: String
    ) throws -> SymmetricKey {
        guard let saltValue = envelope.recoverySalt,
              let salt = Data(base64Encoded: saltValue) else {
            throw CloudSyncError.recoveryUnavailable
        }
        let keyMaterial = try CloudRecoveryKey.keyData(recoveryKey)
        return try unwrapDataKey(
            nonce: envelope.recoveryNonce,
            tag: envelope.recoveryTag,
            ciphertext: envelope.recoveryWrappedKey,
            using: deriveRecoveryKey(keyMaterial: keyMaterial, salt: salt)
        )
    }
}
