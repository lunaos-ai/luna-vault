import Foundation

public enum CloudSyncError: Error, Equatable, CustomStringConvertible {
    case weakPassphrase
    case unsupportedVersion(Int)
    case corruptEnvelope
    case keyDerivationFailed
    case authenticationFailed
    case invalidRecoveryKey
    case recoveryUnavailable
    case recoveryKeyMismatch(expectedFingerprint: String?, enteredFingerprint: String)
    case recoveryKeyNotInstalled(fingerprint: String)
    case recoveryKeyRequired
    case bundleCorrupt
    case randomGenerationFailed

    public var description: String {
        switch self {
        case .weakPassphrase:
            return "sync passphrase must be at least 12 characters"
        case .unsupportedVersion(let version):
            return "unsupported sync bundle version: \(version)"
        case .corruptEnvelope:
            return "corrupt sync bundle"
        case .keyDerivationFailed:
            return "could not derive sync encryption key"
        case .authenticationFailed:
            return "could not decrypt sync bundle; check the passphrase or recovery key"
        case .invalidRecoveryKey:
            return "invalid Vibe Vault recovery key"
        case .recoveryUnavailable:
            return "this backup was not protected with a recovery key"
        case .recoveryKeyMismatch(let expected, let entered):
            if let expected {
                return "entered recovery key \(entered) does not match this backup. Required key: \(expected)"
            }
            return "entered recovery key \(entered) does not match this backup"
        case .recoveryKeyNotInstalled(let fingerprint):
            return "required recovery key \(fingerprint) is not installed"
        case .recoveryKeyRequired:
            return CloudSyncRecoveryCopy.legacyIdentityUnavailable
        case .bundleCorrupt:
            return "bundle authentication failed or bundle is corrupt"
        case .randomGenerationFailed:
            return "could not generate secure random data"
        }
    }
}
