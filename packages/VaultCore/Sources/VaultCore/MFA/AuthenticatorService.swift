import Foundation

public final class AuthenticatorService: @unchecked Sendable {
    let store: AuthenticatorStoring
    let audit: AuditLogging
    let detector: AgentDetecting
    let biometric: BiometricGating
    let sessionId: String

    public init(
        store: AuthenticatorStoring, audit: AuditLogging, detector: AgentDetecting,
        biometric: BiometricGating, sessionId: String = SessionID.current()
    ) {
        self.store = store; self.audit = audit; self.detector = detector
        self.biometric = biometric; self.sessionId = sessionId
    }

    public static func live() throws -> AuthenticatorService {
        AuthenticatorService(
            store: MigratingVaultStore(), audit: try AuditDB(), detector: AgentDetector(),
            biometric: BiometricGate()
        )
    }

    public convenience init(vaultService: VaultService) throws {
        guard let authenticatorStore = vaultService.store as? AuthenticatorStoring else {
            throw AuthenticatorError.unavailable
        }
        self.init(
            store: authenticatorStore, audit: vaultService.audit,
            detector: vaultService.detector, biometric: vaultService.biometric,
            sessionId: vaultService.sessionId
        )
    }

    @discardableResult
    public func add(input: String, issuer: String? = nil, accountName: String? = nil) async throws -> AuthenticatorAccount {
        let parsed = try TOTPGenerator.account(from: input)
        let resolvedIssuer = cleaned(issuer) ?? cleaned(parsed.issuer)
        let resolvedAccount = cleaned(accountName) ?? cleaned(parsed.account)
        guard let resolvedIssuer, let resolvedAccount else { throw AuthenticatorError.invalidIdentity }
        try await biometric.authenticate(reason: "Save authenticator for \(resolvedIssuer)")
        let account = AuthenticatorAccount(
            issuer: resolvedIssuer, accountName: resolvedAccount, secret: parsed.secret,
            algorithm: parsed.algorithm, digits: parsed.digits, period: parsed.period
        )
        try store.addAuthenticator(account)
        try record(account.id, action: .write)
        return account
    }

    public func list() throws -> [AuthenticatorAccountMetadata] {
        try store.listAuthenticators()
    }

    public func code(id: UUID, reason: String = "Show authenticator code", at date: Date = Date()) async throws -> TOTPCode {
        try await biometric.authenticate(reason: reason)
        let account = try store.readAuthenticator(id: id)
        let code = try TOTPGenerator.code(for: TOTPAccount(
            secret: account.secret, issuer: account.issuer, account: account.accountName,
            digits: account.digits, period: account.period, algorithm: account.algorithm
        ), at: date)
        try record(id, action: .read)
        return code
    }

    public func addRecoveryCodes(id: UUID, values: [String]) async throws {
        let cleanedValues = values.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        guard !cleanedValues.isEmpty,
              cleanedValues.allSatisfy({ !$0.isEmpty && $0.count <= 256 }),
              Set(cleanedValues).count == cleanedValues.count,
              cleanedValues.count <= 100 else {
            throw AuthenticatorError.invalidRecoveryCodes
        }
        try await biometric.authenticate(reason: "Save recovery codes")
        var account = try store.readAuthenticator(id: id)
        account.recoveryCodes = cleanedValues.map { RecoveryCode(value: $0) }
        account.updatedAt = Date()
        try update(account, action: .recoveryCodesChanged)
        try record(id, action: .write)
    }

    public func nextRecoveryCode(id: UUID) async throws -> RecoveryCode {
        try await biometric.authenticate(reason: "Show next recovery code")
        let account = try store.readAuthenticator(id: id)
        guard let code = account.recoveryCodes.first(where: { $0.usedAt == nil }) else {
            throw AuthenticatorError.noUnusedRecoveryCodes
        }
        try record(id, action: .read)
        return code
    }

    public func markRecoveryCodeUsed(id: UUID, recoveryCodeID: UUID) async throws {
        try await biometric.authenticate(reason: "Mark recovery code used")
        var account = try store.readAuthenticator(id: id)
        guard let index = account.recoveryCodes.firstIndex(where: { $0.id == recoveryCodeID }) else {
            throw AuthenticatorError.recoveryCodeNotFound(recoveryCodeID)
        }
        account.recoveryCodes[index].usedAt = Date()
        account.updatedAt = Date()
        try update(account, action: .recoveryCodesChanged)
        try record(id, action: .write)
    }

    private func cleaned(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    func record(_ id: UUID, action: AuditEvent.Action) throws {
        let agent = detector.detect()
        try audit.record(AuditEvent(
            secretName: "authenticator:\(id.uuidString)", agent: agent.name,
            agentConfidence: agent.confidence, sessionId: sessionId,
            projectPath: nil, action: action
        ))
    }
}
