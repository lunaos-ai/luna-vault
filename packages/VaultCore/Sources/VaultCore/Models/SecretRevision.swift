import Foundation

public enum SecretRevisionAction: String, Codable, CaseIterable, Sendable {
    case baseline
    case created
    case updated
    case rotated
    case imported
    case restored
    case deleted
    case mfaChanged
    case accessChanged
    case synced

    public var label: String {
        switch self {
        case .baseline: return "History started"
        case .created: return "Created"
        case .updated: return "Updated"
        case .rotated: return "Rotated"
        case .imported: return "Imported"
        case .restored: return "Restored"
        case .deleted: return "Deleted"
        case .mfaChanged: return "MFA changed"
        case .accessChanged: return "AI access changed"
        case .synced: return "Synced"
        }
    }
}

public struct SecretRevision: Codable, Equatable, Identifiable, Sendable {
    public let id: UUID
    public let secret: Secret
    public let capturedAt: Date
    public let action: SecretRevisionAction
    public let sourceHost: String
    public let isDeleted: Bool

    public init(
        id: UUID = UUID(),
        secret: Secret,
        capturedAt: Date = Date(),
        action: SecretRevisionAction,
        sourceHost: String = ProcessInfo.processInfo.hostName,
        isDeleted: Bool = false
    ) {
        self.id = id
        self.secret = secret
        self.capturedAt = capturedAt
        self.action = action
        self.sourceHost = sourceHost
        self.isDeleted = isDeleted
    }
}

public struct SecretRevisionSummary: Equatable, Identifiable, Sendable {
    public let id: UUID
    public let secretName: String
    public let capturedAt: Date
    public let action: SecretRevisionAction
    public let sourceHost: String
    public let isDeleted: Bool

    public init(_ revision: SecretRevision) {
        id = revision.id
        secretName = revision.secret.name
        capturedAt = revision.capturedAt
        action = revision.action
        sourceHost = revision.sourceHost
        isDeleted = revision.isDeleted
    }
}

public protocol VersionedSecretStoring: KeychainStoring {
    func add(_ secret: Secret, revisionAction: SecretRevisionAction) throws
    func update(_ secret: Secret, revisionAction: SecretRevisionAction) throws
    func delete(name: String, revisionAction: SecretRevisionAction) throws
    func revisions(for name: String) throws -> [SecretRevision]
    func allRevisions() throws -> [SecretRevision]
    func mergeRevisions(_ revisions: [SecretRevision]) throws
    func restoreRevision(id: UUID, restoredAt: Date) throws -> Secret
}
