import Foundation

public struct CloudSyncEnvelope: Codable, Equatable, Sendable {
    public let version: Int
    public let createdAt: Date
    public let sourceHost: String
    public let kdf: String
    public let kdfIterations: Int
    public let cipher: String
    public let salt: String
    public let nonce: String
    public let tag: String
    public let ciphertext: String
    public let passphraseNonce: String?
    public let passphraseTag: String?
    public let passphraseWrappedKey: String?
    public let recoveryKdf: String?
    public let recoverySalt: String?
    public let recoveryNonce: String?
    public let recoveryTag: String?
    public let recoveryWrappedKey: String?

    public init(
        version: Int,
        createdAt: Date,
        sourceHost: String,
        kdf: String,
        kdfIterations: Int,
        cipher: String,
        salt: String,
        nonce: String,
        tag: String,
        ciphertext: String,
        passphraseNonce: String? = nil,
        passphraseTag: String? = nil,
        passphraseWrappedKey: String? = nil,
        recoveryKdf: String? = nil,
        recoverySalt: String? = nil,
        recoveryNonce: String? = nil,
        recoveryTag: String? = nil,
        recoveryWrappedKey: String? = nil
    ) {
        self.version = version
        self.createdAt = createdAt
        self.sourceHost = sourceHost
        self.kdf = kdf
        self.kdfIterations = kdfIterations
        self.cipher = cipher
        self.salt = salt
        self.nonce = nonce
        self.tag = tag
        self.ciphertext = ciphertext
        self.passphraseNonce = passphraseNonce
        self.passphraseTag = passphraseTag
        self.passphraseWrappedKey = passphraseWrappedKey
        self.recoveryKdf = recoveryKdf
        self.recoverySalt = recoverySalt
        self.recoveryNonce = recoveryNonce
        self.recoveryTag = recoveryTag
        self.recoveryWrappedKey = recoveryWrappedKey
    }
}

public enum CloudSyncError: Error, Equatable, CustomStringConvertible {
    case weakPassphrase
    case unsupportedVersion(Int)
    case corruptEnvelope
    case keyDerivationFailed
    case authenticationFailed
    case invalidRecoveryKey
    case recoveryUnavailable
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
        case .randomGenerationFailed:
            return "could not generate secure random data"
        }
    }
}
