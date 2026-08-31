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
    public let recoveryKeyID: String?
    public let recoveryProtectedAt: Date?

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
        recoveryWrappedKey: String? = nil,
        recoveryKeyID: String? = nil,
        recoveryProtectedAt: Date? = nil
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
        self.recoveryKeyID = recoveryKeyID
        self.recoveryProtectedAt = recoveryProtectedAt
    }
}
