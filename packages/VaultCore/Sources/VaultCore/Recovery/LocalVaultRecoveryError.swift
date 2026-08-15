import Foundation

public enum LocalVaultRecoveryError: Error, Equatable, CustomStringConvertible {
    case masterKeyUnavailable
    case recoveryEnvelopeMissing
    case vaultMissing
    case corruptEnvelope
    case authenticationFailed
    case unsupportedVersion(Int)

    public var description: String {
        switch self {
        case .masterKeyUnavailable:
            return "vault master key is unavailable; restore it with your recovery key"
        case .recoveryEnvelopeMissing:
            return "local recovery envelope is missing"
        case .vaultMissing:
            return "encrypted vault is missing"
        case .corruptEnvelope:
            return "local recovery envelope is corrupt"
        case .authenticationFailed:
            return "recovery key could not unlock this vault"
        case .unsupportedVersion(let version):
            return "local recovery envelope version \(version) is unsupported"
        }
    }
}
