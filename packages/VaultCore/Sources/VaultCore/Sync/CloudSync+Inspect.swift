import Foundation

public struct CloudSyncBundleInfo: Equatable, Sendable {
    public let version: Int
    public let createdAt: Date
    public let sourceHost: String
    public let hasRecoveryProtection: Bool
    public let recoveryKeyID: String?
    public let recoveryProtectedAt: Date?

    public var recoveryFingerprint: String? {
        recoveryKeyID.map(CloudRecoveryKey.fingerprint(identifier:))
    }

    public var isLegacyRecovery: Bool {
        hasRecoveryProtection && recoveryKeyID == nil
    }

    public init(
        version: Int,
        createdAt: Date,
        sourceHost: String,
        hasRecoveryProtection: Bool,
        recoveryKeyID: String?,
        recoveryProtectedAt: Date?
    ) {
        self.version = version
        self.createdAt = createdAt
        self.sourceHost = sourceHost
        self.hasRecoveryProtection = hasRecoveryProtection
        self.recoveryKeyID = recoveryKeyID
        self.recoveryProtectedAt = recoveryProtectedAt
    }
}

extension CloudSync {
    public static func inspect(_ data: Data) throws -> CloudSyncBundleInfo {
        let envelope: CloudSyncEnvelope
        do {
            envelope = try decoder.decode(CloudSyncEnvelope.self, from: data)
        } catch {
            throw CloudSyncError.corruptEnvelope
        }
        let wrapped = envelope.recoveryKdf != nil
            && envelope.recoverySalt != nil
            && envelope.recoveryNonce != nil
            && envelope.recoveryTag != nil
            && envelope.recoveryWrappedKey != nil
        return CloudSyncBundleInfo(
            version: envelope.version,
            createdAt: envelope.createdAt,
            sourceHost: envelope.sourceHost,
            hasRecoveryProtection: wrapped,
            recoveryKeyID: envelope.recoveryKeyID,
            recoveryProtectedAt: envelope.recoveryProtectedAt
        )
    }
}
