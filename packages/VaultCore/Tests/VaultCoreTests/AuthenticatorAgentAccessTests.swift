import XCTest
@testable import VaultCore

final class AuthenticatorAgentAccessTests: XCTestCase {
    func test_permissionDefaultsOffIncludingLegacyVaults() throws {
        let fixture = AuthenticatorAccessFixture()
        XCTAssertFalse(fixture.account.mcpAllowed)
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(fixture.account)) as? [String: Any])
        json.removeValue(forKey: "mcpAllowed")
        let restored = try JSONDecoder().decode(AuthenticatorAccount.self,
            from: JSONSerialization.data(withJSONObject: json))
        XCTAssertFalse(restored.mcpAllowed)
        XCTAssertTrue(try fixture.agent.list().isEmpty)
        XCTAssertTrue(try fixture.human.listForAgent().isEmpty)
    }

    func test_humanCanGrantAndRevokeAndEveryCodeReadIsAudited() async throws {
        let fixture = AuthenticatorAccessFixture()
        try await fixture.human.setMCPAllowed(id: fixture.account.id, allowed: true)
        XCTAssertEqual(try fixture.agent.listForAgent().map(\.id), [fixture.account.id])
        let code = try await fixture.agent.codeForAgent(id: fixture.account.id, at: Date(timeIntervalSince1970: 59))
        XCTAssertEqual(code.code, "287082")
        XCTAssertEqual(code.secondsRemaining, 1)
        XCTAssertEqual(fixture.audit.events.last?.agent, "codex")
        XCTAssertEqual(fixture.audit.events.last?.action, .read)
        XCTAssertEqual(fixture.audit.events.last?.secretName, "authenticator:\(fixture.account.id.uuidString)")
        try await fixture.agent.setMCPAllowed(id: fixture.account.id, allowed: false)
        do {
            _ = try await fixture.agent.codeForAgent(id: fixture.account.id)
            XCTFail("Revocation did not take effect")
        } catch { XCTAssertEqual(error as? AuthenticatorError, .agentAccessDenied) }
    }

    func test_agentsCannotGrantImportOrReplaceSeeds() async throws {
        let fixture = AuthenticatorAccessFixture()
        do {
            try await fixture.agent.setMCPAllowed(id: fixture.account.id, allowed: true)
            XCTFail("Agent granted itself access")
        } catch { XCTAssertEqual(error as? AuthenticatorError, .humanRequired) }
        do {
            _ = try await fixture.agent.importAccounts([fixture.account], duplicatePolicy: .replace)
            XCTFail("Agent imported authenticator permissions")
        } catch { XCTAssertEqual(error as? AuthenticatorError, .humanRequired) }
        do {
            try await fixture.agent.replaceSeed(id: fixture.account.id, input: "JBSWY3DPEHPK3PXP")
            XCTFail("Agent replaced seed")
        } catch { XCTAssertEqual(error as? AuthenticatorError, .humanRequired) }
        XCTAssertFalse(try fixture.store.readAuthenticator(id: fixture.account.id).mcpAllowed)
    }

    func test_explicitAgentPathChecksPermissionEvenWithUnknownDetector() async throws {
        let fixture = AuthenticatorAccessFixture()
        do {
            _ = try await fixture.human.codeForAgent(id: fixture.account.id)
            XCTFail("Agent API trusted a human detector")
        } catch { XCTAssertEqual(error as? AuthenticatorError, .agentAccessDenied) }
    }

    func test_auditFailureBlocksCodesAndGrants() async throws {
        let fixture = AuthenticatorAccessFixture()
        fixture.audit.fail = true
        do {
            try await fixture.human.setMCPAllowed(id: fixture.account.id, allowed: true)
            XCTFail("Grant succeeded without audit")
        } catch { }
        XCTAssertFalse(try fixture.store.readAuthenticator(id: fixture.account.id).mcpAllowed)
        fixture.audit.fail = false
        try await fixture.human.setMCPAllowed(id: fixture.account.id, allowed: true)
        fixture.audit.fail = true
        do {
            _ = try await fixture.agent.codeForAgent(id: fixture.account.id)
            XCTFail("Code returned without audit")
        } catch { }
    }

    func test_replacingSeedRevokesAgentAccess() async throws {
        let fixture = AuthenticatorAccessFixture()
        try await fixture.human.setMCPAllowed(id: fixture.account.id, allowed: true)
        try await fixture.human.replaceSeed(id: fixture.account.id, input: "JBSWY3DPEHPK3PXP")
        XCTAssertTrue(try fixture.agent.listForAgent().isEmpty)
    }

    func test_revocationDuringUnlockPreventsCodeDelivery() async throws {
        let fixture = AuthenticatorAccessFixture()
        try await fixture.human.setMCPAllowed(id: fixture.account.id, allowed: true)
        let gate = AuthenticatorTestGate { fixture.store.accounts[fixture.account.id]?.mcpAllowed = false }
        let service = AuthenticatorService(store: fixture.store, audit: fixture.audit,
            detector: StubAgentDetector(), biometric: gate)
        do {
            _ = try await service.codeForAgent(id: fixture.account.id)
            XCTFail("Returned a code after permission was revoked while unlocking")
        } catch { XCTAssertEqual(error as? AuthenticatorError, .agentAccessDenied) }
        XCTAssertTrue(fixture.audit.events.allSatisfy { $0.action != .read })
    }

    func test_humanMustUnlockBeforeGrantingAccess() async throws {
        let fixture = AuthenticatorAccessFixture()
        let service = AuthenticatorService(store: fixture.store, audit: fixture.audit,
            detector: StubAgentDetector(), biometric: AuthenticatorTestGate { throw SecretError.biometricDenied })
        do {
            try await service.setMCPAllowed(id: fixture.account.id, allowed: true)
            XCTFail("Granted access without unlocking")
        } catch { }
        XCTAssertFalse(try fixture.store.readAuthenticator(id: fixture.account.id).mcpAllowed)
        XCTAssertTrue(fixture.audit.events.isEmpty)
    }

    func test_permissionSurvivesPersistenceAndUnknownFieldsDoNotChangeIt() async throws {
        let fixture = AuthenticatorAccessFixture()
        try await fixture.human.setMCPAllowed(id: fixture.account.id, allowed: true)
        let account = try fixture.store.readAuthenticator(id: fixture.account.id)
        let roundTrip = try JSONDecoder().decode(AuthenticatorAccount.self, from: JSONEncoder().encode(account))
        XCTAssertTrue(roundTrip.mcpAllowed)
        XCTAssertEqual(roundTrip.secret, account.secret)
    }

    func test_codexShellChildIsDetectedThroughEnvironment() {
        let detector = AgentDetector(env: ["CODEX_THREAD_ID": "test-thread"], parentProcessLookup: { "/bin/zsh" })
        XCTAssertEqual(detector.detect().name, "codex")
        XCTAssertTrue(detector.detect().requiresAuthenticatorAllowlist)
    }

    func test_agentCannotReadAnAuthenticatorWithoutPermission() async throws {
        let fixture = AuthenticatorAccessFixture()
        do {
            _ = try await fixture.agent.code(id: fixture.account.id)
            XCTFail("Unapproved authenticator returned a code")
        } catch { }
        XCTAssertTrue(fixture.audit.events.isEmpty)
    }

    func test_agentsCannotExportSeedsOrReadRecoveryCodes() async throws {
        let fixture = AuthenticatorAccessFixture()
        do {
            _ = try await fixture.agent.accountsForEncryptedBackup()
            XCTFail("Agent exported authenticator seeds")
        } catch { }
        do {
            _ = try await fixture.agent.nextRecoveryCode(id: fixture.account.id)
            XCTFail("Agent read a recovery code")
        } catch { }
    }
}

private final class AuthenticatorTestGate: BiometricGating, @unchecked Sendable {
    let action: () throws -> Void
    init(_ action: @escaping () throws -> Void) { self.action = action }
    func authenticate(reason: String) async throws { try action() }
    func resetSession() {}
    func setSessionWindow(_ seconds: TimeInterval) {}
    func sessionWindowSeconds() -> TimeInterval { 0 }
    func hasValidSession() -> Bool { false }
}

final class AuthenticatorAccessFixture {
    let account = AuthenticatorAccount(
        issuer: "RFC test", accountName: "test-account",
        secret: Data("12345678901234567890".utf8),
        recoveryCodes: [RecoveryCode(value: "synthetic-recovery")]
    )
    let store = AuthenticatorMemoryStore()
    let audit = AuthenticatorMemoryAudit()
    lazy var agent = service(agent: true)
    lazy var human = service(agent: false)

    init() { store.accounts[account.id] = account }

    func service(agent: Bool) -> AuthenticatorService {
        AuthenticatorService(
            store: store, audit: audit,
            detector: StubAgentDetector(DetectedAgent(
                name: agent ? "codex" : "terminal", confidence: .high,
                source: agent ? "mcp-initialize" : "parent-process:zsh"
            )), biometric: NoopBiometricGate(), sessionId: "synthetic-session"
        )
    }
}

final class AuthenticatorMemoryStore: AuthenticatorStoring, @unchecked Sendable {
    var accounts: [UUID: AuthenticatorAccount] = [:]
    func addAuthenticator(_ account: AuthenticatorAccount) throws { accounts[account.id] = account }
    func updateAuthenticator(_ account: AuthenticatorAccount) throws { accounts[account.id] = account }
    func readAuthenticator(id: UUID) throws -> AuthenticatorAccount {
        guard let account = accounts[id] else { throw AuthenticatorError.notFound(id) }
        return account
    }
    func listAuthenticators() throws -> [AuthenticatorAccountMetadata] {
        accounts.values.map(AuthenticatorAccountMetadata.init)
    }
    func allAuthenticators() throws -> [AuthenticatorAccount] { Array(accounts.values) }
    func deleteAuthenticator(id: UUID) throws { accounts.removeValue(forKey: id) }
}

final class AuthenticatorMemoryAudit: AuditLogging, @unchecked Sendable {
    var events: [AuditEvent] = []
    var fail = false
    func record(_ event: AuditEvent) throws {
        if fail { throw SecretError.biometricDenied }
        events.append(event)
    }
    func query(_ filter: AuditFilter) throws -> [AuditEvent] { events }
    func purge(olderThan: Date) throws -> Int { 0 }
}
