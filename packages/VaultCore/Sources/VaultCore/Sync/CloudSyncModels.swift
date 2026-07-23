import Foundation

public struct CloudSyncSnapshot: Codable, Equatable, Sendable {
    public let version: Int
    public let exportedAt: Date
    public let sourceHost: String
    public let secrets: [CloudSyncSecret]

    public init(
        version: Int = 1,
        exportedAt: Date = Date(),
        sourceHost: String = ProcessInfo.processInfo.hostName,
        secrets: [CloudSyncSecret]
    ) {
        self.version = version
        self.exportedAt = exportedAt
        self.sourceHost = sourceHost
        self.secrets = secrets
    }
}

public struct CloudSyncSecret: Codable, Equatable, Sendable {
    public let name: String
    public let value: String
    public let createdAt: Date
    public let updatedAt: Date
    public let notes: String?
    public let expiresAt: Date?
    public let rotateEveryDays: Int?
    public let lastRotatedAt: Date?
    public let mcpAllowed: Bool
    public let totpAuthURL: String?

    enum CodingKeys: String, CodingKey {
        case name
        case value
        case createdAt
        case updatedAt
        case notes
        case expiresAt
        case rotateEveryDays
        case lastRotatedAt
        case mcpAllowed
        case totpAuthURL
    }

    public init(
        name: String,
        value: String,
        createdAt: Date? = nil,
        updatedAt: Date = Date(),
        notes: String? = nil,
        expiresAt: Date? = nil,
        rotateEveryDays: Int? = nil,
        lastRotatedAt: Date? = nil,
        mcpAllowed: Bool = false,
        totpAuthURL: String? = nil
    ) {
        self.name = name
        self.value = value
        self.createdAt = createdAt ?? updatedAt
        self.updatedAt = updatedAt
        self.notes = notes
        self.expiresAt = expiresAt
        self.rotateEveryDays = rotateEveryDays
        self.lastRotatedAt = lastRotatedAt
        self.mcpAllowed = mcpAllowed
        self.totpAuthURL = totpAuthURL
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = try container.decode(String.self, forKey: .name)
        value = try container.decode(String.self, forKey: .value)
        updatedAt = try container.decode(Date.self, forKey: .updatedAt)
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt) ?? updatedAt
        notes = try container.decodeIfPresent(String.self, forKey: .notes)
        expiresAt = try container.decodeIfPresent(Date.self, forKey: .expiresAt)
        rotateEveryDays = try container.decodeIfPresent(Int.self, forKey: .rotateEveryDays)
        lastRotatedAt = try container.decodeIfPresent(Date.self, forKey: .lastRotatedAt)
        mcpAllowed = try container.decodeIfPresent(Bool.self, forKey: .mcpAllowed) ?? false
        totpAuthURL = try container.decodeIfPresent(String.self, forKey: .totpAuthURL)
    }

    public init(secret: Secret) {
        self.init(
            name: secret.name,
            value: secret.value,
            createdAt: secret.createdAt,
            updatedAt: secret.updatedAt,
            notes: secret.notes,
            expiresAt: secret.expiresAt,
            rotateEveryDays: secret.rotateEveryDays,
            lastRotatedAt: secret.lastRotatedAt,
            mcpAllowed: secret.mcpAllowed,
            totpAuthURL: secret.totpAuthURL
        )
    }

    public func asSecret() -> Secret {
        Secret(
            name: name,
            value: value,
            updatedAt: updatedAt,
            createdAt: createdAt,
            notes: notes,
            expiresAt: expiresAt,
            rotateEveryDays: rotateEveryDays,
            lastRotatedAt: lastRotatedAt,
            mcpAllowed: mcpAllowed,
            hasTOTP: totpAuthURL != nil,
            totpAuthURL: totpAuthURL
        )
    }
}

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
}

public enum CloudSyncError: Error, Equatable, CustomStringConvertible {
    case weakPassphrase
    case unsupportedVersion(Int)
    case corruptEnvelope
    case keyDerivationFailed
    case authenticationFailed

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
            return "could not decrypt sync bundle; check the passphrase"
        }
    }
}
