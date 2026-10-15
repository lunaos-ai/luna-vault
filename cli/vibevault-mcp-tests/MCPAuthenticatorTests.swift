import XCTest
import VaultCore
@testable import vibevault_mcp

final class MCPAuthenticatorTests: XCTestCase {
    func test_discoveryExposesCodeToolsWithoutEnrollmentOrGrantTools() {
        let tools = MCPTools.definitions.map(\.name)
        XCTAssertTrue(tools.contains("list_authenticators"))
        XCTAssertTrue(tools.contains("get_authenticator_code"))
        XCTAssertTrue(tools.contains("revoke_authenticator_access"))
        XCTAssertFalse(tools.contains("set_authenticator_access"))
    }

    func test_listOmitsUnapprovedAccountsAndAllCredentialMaterial() async throws {
        let fixture = MCPAuthenticatorFixture()
        let result = await MCPTools.call(name: "list_authenticators", arguments: [:], context: fixture.context)
        let text = try responseText(result)
        XCTAssertTrue(text.contains(fixture.allowed.id.uuidString))
        XCTAssertFalse(text.contains(fixture.blocked.id.uuidString))
        XCTAssertFalse(text.contains("secret"))
        XCTAssertFalse(text.contains("recovery"))
    }

    func test_codeIsAuditedRevocableAndNeverReturnsSetupOrRecoveryKeys() async throws {
        let fixture = MCPAuthenticatorFixture()
        let args: [String: Any] = ["id": fixture.allowed.id.uuidString]
        let result = await MCPTools.call(name: "get_authenticator_code", arguments: args, context: fixture.context)
        let text = try responseText(result)
        let payload = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(text.utf8)) as? [String: Any])
        XCTAssertEqual(Set(payload.keys), ["id", "code", "valid_for_seconds", "period"])
        XCTAssertEqual((payload["code"] as? String)?.count, 6)
        XCTAssertTrue((1...30).contains(try XCTUnwrap(payload["valid_for_seconds"] as? Int)))
        XCTAssertEqual(fixture.audit.events.last?.action, .read)
        XCTAssertEqual(fixture.audit.events.last?.agent, "codex")
        let log = await MCPTools.call(name: "get_audit_log",
            arguments: ["secret": "authenticator:\(fixture.allowed.id.uuidString)"], context: fixture.context)
        XCTAssertTrue(try responseText(log).contains("codex"))
        XCTAssertFalse(try responseText(log).contains(try XCTUnwrap(payload["code"] as? String)))
        _ = await MCPTools.call(name: "revoke_authenticator_access", arguments: args, context: fixture.context)
        let denied = await MCPTools.call(name: "get_authenticator_code", arguments: args, context: fixture.context)
        XCTAssertEqual(denied["isError"] as? Bool, true)
        XCTAssertEqual(fixture.audit.events.filter { $0.action == .read }.count, 1)
    }

    func test_deniesBlockedUnknownAndMalformedIDs() async throws {
        let fixture = MCPAuthenticatorFixture()
        for id in [fixture.blocked.id.uuidString, UUID().uuidString, "not-an-id"] {
            let result = await MCPTools.call(name: "get_authenticator_code", arguments: ["id": id], context: fixture.context)
            XCTAssertEqual(result["isError"] as? Bool, true)
        }
        XCTAssertTrue(fixture.audit.events.isEmpty)
        let revoke = await MCPTools.call(name: "revoke_authenticator_access",
            arguments: ["id": fixture.blocked.id.uuidString], context: fixture.context)
        XCTAssertEqual(revoke["isError"] as? Bool, true)
    }

    func test_auditFailureNeverReturnsACode() async throws {
        let fixture = MCPAuthenticatorFixture()
        fixture.audit.fail = true
        let result = await MCPTools.call(name: "get_authenticator_code",
            arguments: ["id": fixture.allowed.id.uuidString], context: fixture.context)
        XCTAssertEqual(result["isError"] as? Bool, true)
        XCTAssertFalse(try responseText(result).contains("\"code\""))
    }

    private func responseText(_ result: [String: Any]) throws -> String {
        try XCTUnwrap((result["content"] as? [[String: Any]])?.first?["text"] as? String)
    }
}

private final class MCPAuthenticatorFixture {
    let allowed = AuthenticatorAccount(issuer: "PushCI", accountName: "synthetic-user",
        secret: Data("12345678901234567890".utf8), mcpAllowed: true)
    let blocked = AuthenticatorAccount(issuer: "Private", accountName: "hidden",
        secret: Data("abcdefghijklmnopqrst".utf8))
    let store = MCPAuthenticatorStore()
    let audit = MCPAuthenticatorAudit()
    lazy var context: MCPContext = {
        let detector = MCPAgentDetector(env: [:])
        detector.setMCPClientName("codex")
        return MCPContext(service: VaultService(store: store, audit: audit, detector: detector,
            biometric: NoopBiometricGate()), clientName: "codex", prefs: InMemoryPrefs(), registry: ProviderRegistry())
    }()
    init() { store.accounts = [allowed.id: allowed, blocked.id: blocked] }
}

private final class MCPAuthenticatorStore: KeychainStoring, AuthenticatorStoring, @unchecked Sendable {
    var accounts: [UUID: AuthenticatorAccount] = [:]
    func addAuthenticator(_ account: AuthenticatorAccount) throws { accounts[account.id] = account }
    func updateAuthenticator(_ account: AuthenticatorAccount) throws { accounts[account.id] = account }
    func readAuthenticator(id: UUID) throws -> AuthenticatorAccount {
        guard let account = accounts[id] else { throw AuthenticatorError.notFound(id) }
        return account
    }
    func listAuthenticators() throws -> [AuthenticatorAccountMetadata] { accounts.values.map(AuthenticatorAccountMetadata.init) }
    func allAuthenticators() throws -> [AuthenticatorAccount] { Array(accounts.values) }
    func deleteAuthenticator(id: UUID) throws { accounts.removeValue(forKey: id) }
    func add(_ secret: Secret) throws {}
    func update(_ secret: Secret) throws {}
    func read(name: String) throws -> Secret { throw SecretError.notFound(name: name) }
    func delete(name: String) throws {}
    func list() throws -> [Secret] { [] }
    func exists(name: String) throws -> Bool { false }
}

private final class MCPAuthenticatorAudit: AuditLogging, @unchecked Sendable {
    var events: [AuditEvent] = []
    var fail = false
    func record(_ event: AuditEvent) throws {
        if fail { throw SecretError.biometricDenied }
        events.append(event)
    }
    func query(_ filter: AuditFilter) throws -> [AuditEvent] { events }
    func purge(olderThan: Date) throws -> Int { 0 }
}
