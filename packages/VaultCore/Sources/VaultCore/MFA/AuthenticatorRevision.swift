import Foundation

public enum AuthenticatorRevisionAction: String, Codable, Equatable, Sendable {
    case created
    case updated
    case metadataEdited
    case seedReplaced
    case recoveryCodesChanged
    case imported
    case synced
    case deleted
}

public struct AuthenticatorRevision: Codable, Equatable, Identifiable, Sendable {
    public let id: UUID
    public let account: AuthenticatorAccount
    public let capturedAt: Date
    public let action: AuthenticatorRevisionAction
    public let sourceHost: String
    public let isDeleted: Bool

    public init(
        id: UUID = UUID(), account: AuthenticatorAccount,
        capturedAt: Date = Date(), action: AuthenticatorRevisionAction,
        sourceHost: String = ProcessInfo.processInfo.hostName, isDeleted: Bool = false
    ) {
        self.id = id; self.account = account; self.capturedAt = capturedAt
        self.action = action; self.sourceHost = sourceHost; self.isDeleted = isDeleted
    }
}

public protocol VersionedAuthenticatorStoring: AuthenticatorStoring {
    func addAuthenticator(_ account: AuthenticatorAccount, action: AuthenticatorRevisionAction) throws
    func updateAuthenticator(_ account: AuthenticatorAccount, action: AuthenticatorRevisionAction) throws
    func deleteAuthenticator(id: UUID, action: AuthenticatorRevisionAction) throws
    func authenticatorRevisions(id: UUID) throws -> [AuthenticatorRevision]
    func allAuthenticatorRevisions() throws -> [AuthenticatorRevision]
    func mergeAuthenticatorRevisions(_ revisions: [AuthenticatorRevision]) throws
}
