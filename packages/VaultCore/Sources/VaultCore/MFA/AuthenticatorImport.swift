import Foundation

public enum AuthenticatorDuplicatePolicy: Sendable {
    case skip
    case replace
}

public struct AuthenticatorImportResult: Equatable, Sendable {
    public let imported: [UUID]
    public let replaced: [UUID]
    public let skipped: [UUID]

    public init(imported: [UUID], replaced: [UUID], skipped: [UUID]) {
        self.imported = imported; self.replaced = replaced; self.skipped = skipped
    }
}

extension AuthenticatorService {
    public func accountsForEncryptedBackup() async throws -> [AuthenticatorAccount] {
        try await biometric.authenticate(reason: "Export authenticators to encrypted backup")
        return try store.allAuthenticators()
    }

    public func revisionsForEncryptedBackup() throws -> [AuthenticatorRevision] {
        guard let store = store as? VersionedAuthenticatorStoring else { return [] }
        return try store.allAuthenticatorRevisions()
    }

    public func mergeRevisionsFromEncryptedBackup(_ revisions: [AuthenticatorRevision]) throws {
        guard let store = store as? VersionedAuthenticatorStoring else { return }
        try store.mergeAuthenticatorRevisions(revisions)
    }

    public func importAccounts(
        _ accounts: [AuthenticatorAccount],
        duplicatePolicy: AuthenticatorDuplicatePolicy
    ) async throws -> AuthenticatorImportResult {
        guard accounts.count <= 10_000 else { throw TOTPError.invalidParameter("account count") }
        try await biometric.authenticate(reason: "Import authenticators from encrypted backup")
        var imported: [UUID] = []
        var replaced: [UUID] = []
        var skipped: [UUID] = []
        for account in accounts {
            do {
                try addImported(account)
                try record(account.id, action: .importEvent)
                imported.append(account.id)
            } catch AuthenticatorError.duplicate(let existingID) {
                switch duplicatePolicy {
                case .skip:
                    skipped.append(account.id)
                case .replace:
                    if let versioned = store as? VersionedAuthenticatorStoring {
                        try versioned.deleteAuthenticator(id: existingID, action: .synced)
                    } else {
                        try store.deleteAuthenticator(id: existingID)
                    }
                    try addImported(account)
                    try record(account.id, action: .importEvent)
                    replaced.append(account.id)
                }
            }
        }
        return AuthenticatorImportResult(
            imported: imported, replaced: replaced, skipped: skipped
        )
    }

    private func addImported(_ account: AuthenticatorAccount) throws {
        if let versioned = store as? VersionedAuthenticatorStoring {
            try versioned.addAuthenticator(account, action: .imported)
        } else {
            try store.addAuthenticator(account)
        }
    }
}
