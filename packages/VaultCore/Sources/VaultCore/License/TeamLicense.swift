import Foundation

/// Team license payload — signed offline, verified against `LicensePublicKey`.
public struct TeamLicense: Codable, Equatable, Sendable {
    public let tier: String
    public let email: String
    public let seats: Int
    public let issuedAt: Date
    public let expiresAt: Date?
    public let orderId: String
    public let productId: String

    public init(
        tier: String = "team",
        email: String,
        seats: Int,
        issuedAt: Date = Date(),
        expiresAt: Date? = nil,
        orderId: String,
        productId: String
    ) {
        self.tier = tier
        self.email = email
        self.seats = seats
        self.issuedAt = issuedAt
        self.expiresAt = expiresAt
        self.orderId = orderId
        self.productId = productId
    }

    public var isExpired: Bool {
        guard let expiresAt else { return false }
        return expiresAt < Date()
    }

    /// Paid offline tiers issued by Lemon Squeezy / `vibevault license issue`.
    public static let paidTiers: Set<String> = ["team", "studio", "company"]

    public var isLicensed: Bool {
        seats > 0 && !isExpired && Self.paidTiers.contains(tier.lowercased())
    }

    /// Alias for `isLicensed` (Team badge / Settings).
    public var isTeam: Bool { isLicensed }
}

public enum LicenseError: Error, CustomStringConvertible, Equatable {
    case invalidFormat
    case badSignature
    case expired
    case decodeFailed
    case missingPrivateKey
    case notLicensed

    public var description: String {
        switch self {
        case .invalidFormat: return "invalid license format (expected VV1.payload.sig)"
        case .badSignature: return "license signature invalid"
        case .expired: return "license expired"
        case .decodeFailed: return "could not decode license payload"
        case .missingPrivateKey: return "missing signing key (VIBEVAULT_LICENSE_PRIVATE_KEY)"
        case .notLicensed: return "Team license required"
        }
    }
}
