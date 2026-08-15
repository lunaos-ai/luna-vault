import Foundation

public struct RecoveryCode: Codable, Equatable, Identifiable, Sendable {
    public let id: UUID
    public let value: String
    public var usedAt: Date?

    public init(id: UUID = UUID(), value: String, usedAt: Date? = nil) {
        self.id = id
        self.value = value
        self.usedAt = usedAt
    }
}

public struct AuthenticatorAccount: Codable, Equatable, Identifiable, Sendable {
    public let id: UUID
    public var issuer: String
    public var accountName: String
    public var secret: Data
    public var algorithm: TOTPAlgorithm
    public var digits: Int
    public var period: Int
    public let createdAt: Date
    public var updatedAt: Date
    public var favorite: Bool
    public var recoveryCodes: [RecoveryCode]

    public init(
        id: UUID = UUID(), issuer: String, accountName: String, secret: Data,
        algorithm: TOTPAlgorithm = .sha1, digits: Int = 6, period: Int = 30,
        createdAt: Date = Date(), updatedAt: Date = Date(), favorite: Bool = false,
        recoveryCodes: [RecoveryCode] = []
    ) {
        self.id = id; self.issuer = issuer; self.accountName = accountName
        self.secret = secret; self.algorithm = algorithm; self.digits = digits
        self.period = period; self.createdAt = createdAt; self.updatedAt = updatedAt
        self.favorite = favorite; self.recoveryCodes = recoveryCodes
    }
}

public struct AuthenticatorAccountMetadata: Codable, Equatable, Identifiable, Sendable {
    public let id: UUID
    public let issuer: String
    public let accountName: String
    public let algorithm: TOTPAlgorithm
    public let digits: Int
    public let period: Int
    public let createdAt: Date
    public let updatedAt: Date
    public let favorite: Bool
    public let recoveryCodeCount: Int
    public let unusedRecoveryCodeCount: Int

    public init(_ account: AuthenticatorAccount) {
        id = account.id; issuer = account.issuer; accountName = account.accountName
        algorithm = account.algorithm; digits = account.digits; period = account.period
        createdAt = account.createdAt; updatedAt = account.updatedAt; favorite = account.favorite
        recoveryCodeCount = account.recoveryCodes.count
        unusedRecoveryCodeCount = account.recoveryCodes.filter { $0.usedAt == nil }.count
    }
}

public enum AuthenticatorError: Error, Equatable, CustomStringConvertible {
    case unavailable
    case notFound(UUID)
    case duplicate(UUID)
    case invalidIdentity
    case invalidRecoveryCodes
    case noUnusedRecoveryCodes
    case recoveryCodeNotFound(UUID)

    public var description: String {
        switch self {
        case .unavailable: return "standalone authenticators require the encrypted vault"
        case .notFound: return "authenticator account not found"
        case .duplicate: return "this authenticator account is already saved"
        case .invalidIdentity: return "issuer and account name are required"
        case .invalidRecoveryCodes: return "recovery codes must be non-empty and unique"
        case .noUnusedRecoveryCodes: return "no unused recovery codes remain"
        case .recoveryCodeNotFound: return "recovery code not found"
        }
    }
}

extension AuthenticatorAccount {
    func validate() throws {
        let cleanIssuer = issuer.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanAccount = accountName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanIssuer.isEmpty, !cleanAccount.isEmpty,
              cleanIssuer.utf8.count <= 1_024, cleanAccount.utf8.count <= 2_048 else {
            throw AuthenticatorError.invalidIdentity
        }
        guard !secret.isEmpty, secret.count <= 1_024 else { throw TOTPError.invalidSecret }
        guard digits == 6 || digits == 8 else { throw TOTPError.invalidParameter("digits") }
        guard (15...300).contains(period) else { throw TOTPError.invalidParameter("period") }
        guard recoveryCodes.count <= 100,
              recoveryCodes.allSatisfy({ !$0.value.isEmpty && $0.value.count <= 256 }) else {
            throw AuthenticatorError.invalidRecoveryCodes
        }
    }
}
