import Foundation

extension AuthenticatorService {
    public func updateMetadata(
        id: UUID, issuer: String, accountName: String, favorite: Bool
    ) async throws {
        let cleanIssuer = issuer.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanAccount = accountName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanIssuer.isEmpty, !cleanAccount.isEmpty,
              cleanIssuer.count <= 256, cleanAccount.count <= 512 else {
            throw AuthenticatorError.invalidIdentity
        }
        try await biometric.authenticate(reason: "Update authenticator")
        var account = try store.readAuthenticator(id: id)
        account.issuer = cleanIssuer
        account.accountName = cleanAccount
        account.favorite = favorite
        account.updatedAt = Date()
        try update(account, action: .metadataEdited)
        try record(id, action: .write)
    }

    public func delete(id: UUID) async throws {
        try await biometric.authenticate(reason: "Delete authenticator")
        try store.deleteAuthenticator(id: id)
        try record(id, action: .delete)
    }

    public func replaceSeed(id: UUID, input: String) async throws {
        let parsed = try TOTPGenerator.account(from: input)
        try await biometric.authenticate(reason: "Replace authenticator setup key")
        var account = try store.readAuthenticator(id: id)
        account.secret = parsed.secret
        account.algorithm = parsed.algorithm
        account.digits = parsed.digits
        account.period = parsed.period
        account.updatedAt = Date()
        try update(account, action: .seedReplaced)
        try record(id, action: .write)
    }

    @discardableResult
    public func convertAttachedTOTP(
        secretName: String, vaultService: VaultService
    ) async throws -> AuthenticatorAccount {
        let secret = try await vaultService.read(
            name: secretName, reason: "Convert attached MFA for \(secretName)"
        )
        guard let uri = secret.totpAuthURL else { throw TOTPError.invalidURL }
        let account = try await add(input: uri)
        try await vaultService.setTOTP(name: secretName, authURL: nil)
        return account
    }

    func update(
        _ account: AuthenticatorAccount, action: AuthenticatorRevisionAction
    ) throws {
        if let versioned = store as? VersionedAuthenticatorStoring {
            try versioned.updateAuthenticator(account, action: action)
        } else {
            try store.updateAuthenticator(account)
        }
    }
}
