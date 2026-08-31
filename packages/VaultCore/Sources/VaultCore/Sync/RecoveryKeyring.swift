import Foundation

public enum RecoveryKeyRole: String, Codable, Equatable, Sendable {
    case active
    case retained
}

public struct RecoveryKeyRecord: Codable, Equatable, Sendable, Identifiable {
    public var id: String { identifier }
    public let identifier: String
    public let canonicalKey: String
    public let createdAt: Date
    public let importedAt: Date?
    public var role: RecoveryKeyRole

    public var fingerprint: String {
        CloudRecoveryKey.fingerprint(identifier: identifier)
    }

    public var summary: RecoveryKeySummary {
        RecoveryKeySummary(
            identifier: identifier,
            fingerprint: fingerprint,
            createdAt: createdAt,
            importedAt: importedAt,
            isActive: role == .active
        )
    }

    public init(
        identifier: String,
        canonicalKey: String,
        createdAt: Date,
        importedAt: Date? = nil,
        role: RecoveryKeyRole
    ) {
        self.identifier = identifier
        self.canonicalKey = canonicalKey
        self.createdAt = createdAt
        self.importedAt = importedAt
        self.role = role
    }
}

public struct RecoveryKeyring: Codable, Equatable, Sendable {
    public internal(set) var records: [RecoveryKeyRecord]

    public init(records: [RecoveryKeyRecord] = []) {
        self.records = records
    }

    public var active: RecoveryKeyRecord? {
        records.first { $0.role == .active }
    }

    public var activeCanonicalKey: String? { active?.canonicalKey }

    public func record(identifier: String) -> RecoveryKeyRecord? {
        records.first { $0.identifier == identifier }
    }

    public var summaries: [RecoveryKeySummary] {
        records.map(\.summary)
    }
}

public struct RecoveryKeySummary: Equatable, Sendable, Identifiable {
    public var id: String { identifier }
    public let identifier: String
    public let fingerprint: String
    public let createdAt: Date
    public let importedAt: Date?
    public let isActive: Bool
}
