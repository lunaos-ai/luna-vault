import Foundation

public protocol AuthenticatorStoring: Sendable {
    func addAuthenticator(_ account: AuthenticatorAccount) throws
    func updateAuthenticator(_ account: AuthenticatorAccount) throws
    func readAuthenticator(id: UUID) throws -> AuthenticatorAccount
    func listAuthenticators() throws -> [AuthenticatorAccountMetadata]
    func allAuthenticators() throws -> [AuthenticatorAccount]
    func deleteAuthenticator(id: UUID) throws
}

extension EncryptedVaultStore: VersionedAuthenticatorStoring {
    public func addAuthenticator(_ account: AuthenticatorAccount) throws {
        try addAuthenticator(account, action: .created)
    }

    public func addAuthenticator(
        _ account: AuthenticatorAccount, action: AuthenticatorRevisionAction
    ) throws {
        try account.validate()
        try queue.sync {
            var document = try loadDocument()
            guard document.authenticatorAccounts[account.id] == nil else {
                throw AuthenticatorError.duplicate(account.id)
            }
            let key = try masterKey()
            let fingerprint = account.seedFingerprint(using: key)
            if let duplicate = document.authenticatorAccounts.values.first(where: {
                $0.seedFingerprint(using: key) == fingerprint
            }) {
                throw AuthenticatorError.duplicate(duplicate.id)
            }
            document.authenticatorAccounts[account.id] = account
            appendAuthenticatorRevision(account, action: action, to: &document)
            try saveDocument(document)
        }
    }

    public func updateAuthenticator(_ account: AuthenticatorAccount) throws {
        try updateAuthenticator(account, action: .updated)
    }

    public func updateAuthenticator(
        _ account: AuthenticatorAccount, action: AuthenticatorRevisionAction
    ) throws {
        try account.validate()
        try queue.sync {
            var document = try loadDocument()
            guard document.authenticatorAccounts[account.id] != nil else {
                throw AuthenticatorError.notFound(account.id)
            }
            document.authenticatorAccounts[account.id] = account
            appendAuthenticatorRevision(account, action: action, to: &document)
            try saveDocument(document)
        }
    }

    public func readAuthenticator(id: UUID) throws -> AuthenticatorAccount {
        try queue.sync {
            guard let account = try loadDocument().authenticatorAccounts[id] else {
                throw AuthenticatorError.notFound(id)
            }
            return account
        }
    }

    public func listAuthenticators() throws -> [AuthenticatorAccountMetadata] {
        try queue.sync {
            try loadDocument().authenticatorAccounts.values
                .map(AuthenticatorAccountMetadata.init)
                .sorted {
                    if $0.favorite != $1.favorite { return $0.favorite && !$1.favorite }
                    if $0.issuer != $1.issuer { return $0.issuer.localizedCaseInsensitiveCompare($1.issuer) == .orderedAscending }
                    return $0.accountName.localizedCaseInsensitiveCompare($1.accountName) == .orderedAscending
                }
        }
    }

    public func allAuthenticators() throws -> [AuthenticatorAccount] {
        try queue.sync {
            try loadDocument().authenticatorAccounts.values.sorted { $0.id.uuidString < $1.id.uuidString }
        }
    }

    public func deleteAuthenticator(id: UUID) throws {
        try deleteAuthenticator(id: id, action: .deleted)
    }

    public func deleteAuthenticator(id: UUID, action: AuthenticatorRevisionAction) throws {
        try queue.sync {
            var document = try loadDocument()
            guard let removed = document.authenticatorAccounts.removeValue(forKey: id) else {
                throw AuthenticatorError.notFound(id)
            }
            appendAuthenticatorRevision(
                removed, action: action, isDeleted: true, to: &document
            )
            try saveDocument(document)
        }
    }

    public func authenticatorRevisions(id: UUID) throws -> [AuthenticatorRevision] {
        try queue.sync {
            try loadDocument().authenticatorRevisions
                .filter { $0.account.id == id }
                .sorted { $0.capturedAt > $1.capturedAt }
        }
    }

    public func allAuthenticatorRevisions() throws -> [AuthenticatorRevision] {
        try queue.sync { try loadDocument().authenticatorRevisions }
    }

    public func mergeAuthenticatorRevisions(_ revisions: [AuthenticatorRevision]) throws {
        guard !revisions.isEmpty else { return }
        try queue.sync {
            var document = try loadDocument()
            var ids = Set(document.authenticatorRevisions.map(\.id))
            document.authenticatorRevisions.append(
                contentsOf: revisions.filter { ids.insert($0.id).inserted }
            )
            pruneAuthenticatorRevisions(in: &document)
            try saveDocument(document)
        }
    }

    private func appendAuthenticatorRevision(
        _ account: AuthenticatorAccount, action: AuthenticatorRevisionAction,
        isDeleted: Bool = false, to document: inout VaultDocument
    ) {
        document.authenticatorRevisions.append(AuthenticatorRevision(
            account: account, action: action, isDeleted: isDeleted
        ))
        pruneAuthenticatorRevisions(in: &document)
    }

    private func pruneAuthenticatorRevisions(in document: inout VaultDocument) {
        document.authenticatorRevisions = Dictionary(
            grouping: document.authenticatorRevisions, by: { $0.account.id }
        ).values.flatMap {
            $0.sorted { $0.capturedAt > $1.capturedAt }
                .prefix(EncryptedVaultStore.revisionRetentionPerSecret)
        }
    }
}
