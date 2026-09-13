import Foundation

extension CloudSync {
    struct RecoveryWrap {
        let salt: Data
        let box: AES.GCM.SealedBox
        let keyID: String
        let protectedAt: Date
    }

    static func wrapRecovery(dataKeyBytes: Data, recoveryKey: String) throws -> RecoveryWrap {
        let keyMaterial = try CloudRecoveryKey.keyData(recoveryKey)
        let salt = try secureRandomData(count: 32)
        let box = try AES.GCM.seal(
            dataKeyBytes,
            using: deriveRecoveryKey(keyMaterial: keyMaterial, salt: salt)
        )
        return RecoveryWrap(
            salt: salt,
            box: box,
            keyID: try CloudRecoveryKey.identifier(recoveryKey),
            protectedAt: Date()
        )
    }
}
