import XCTest
@testable import VaultCore

final class MCPAllowedTests: XCTestCase {
    func test_secret_defaults_to_mcpAllowed_false() {
        let s = Secret(name: "X", value: "v")
        XCTAssertFalse(s.mcpAllowed)
    }

    func test_keychain_roundtrip_preserves_mcpAllowed_true() throws {
        let store = KeychainStore(service: "dev.vibevault.test.\(UUID().uuidString)", accessGroup: nil)
        let secret = Secret(name: "MCP_ON", value: "v", mcpAllowed: true)
        try store.add(secret)
        let read = try store.read(name: "MCP_ON")
        XCTAssertTrue(read.mcpAllowed)
        try store.delete(name: "MCP_ON")
    }

    func test_keychain_roundtrip_preserves_mcpAllowed_false() throws {
        let store = KeychainStore(service: "dev.vibevault.test.\(UUID().uuidString)", accessGroup: nil)
        let secret = Secret(name: "MCP_OFF", value: "v")
        try store.add(secret)
        let read = try store.read(name: "MCP_OFF")
        XCTAssertFalse(read.mcpAllowed)
        try store.delete(name: "MCP_OFF")
    }

    func test_setMCPAllowed_flips_flag() async throws {
        let dbURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("mcp-\(UUID().uuidString).db")
        defer { try? FileManager.default.removeItem(at: dbURL) }
        let store = MemStore()
        try store.add(Secret(name: "T", value: "v", mcpAllowed: false))
        let service = VaultService(
            store: store, audit: try AuditDB(url: dbURL),
            detector: StubAgentDetector(), biometric: NoopBiometricGate()
        )
        try await service.setMCPAllowed(name: "T", allowed: true)
        XCTAssertTrue(try store.read(name: "T").mcpAllowed)
        try await service.setMCPAllowed(name: "T", allowed: false)
        XCTAssertFalse(try store.read(name: "T").mcpAllowed)
    }

    func test_agent_read_denied_when_not_mcpAllowed() async throws {
        let service = try makeService(
            detector: StubAgentDetector(
                DetectedAgent(name: "cursor", confidence: .high, source: "LUNA_AGENT")
            )
        )
        try service.store.add(Secret(name: "T", value: "secret-v"))
        do {
            _ = try await service.read(name: "T")
            XCTFail("expected mcpDenied")
        } catch SecretError.mcpDenied(let name) {
            XCTAssertEqual(name, "T")
        }
    }

    func test_agent_read_succeeds_when_mcpAllowed() async throws {
        let service = try makeService(
            detector: StubAgentDetector(
                DetectedAgent(name: "cursor", confidence: .high, source: "mcp-initialize")
            )
        )
        try service.store.add(Secret(name: "T", value: "secret-v", mcpAllowed: true))
        let secret = try await service.read(name: "T")
        XCTAssertEqual(secret.value, "secret-v")
    }

    func test_human_cli_read_ignores_mcpAllowed() async throws {
        let service = try makeService(
            detector: StubAgentDetector(
                DetectedAgent(name: "zsh", confidence: .low, source: "parent-process:zsh")
            )
        )
        try service.store.add(Secret(name: "T", value: "secret-v"))
        let secret = try await service.read(name: "T")
        XCTAssertEqual(secret.value, "secret-v")
    }

    func test_blockedNames_only_when_agent_requires_allowlist() {
        let secrets = [
            Secret(name: "OPEN", value: "a", mcpAllowed: true),
            Secret(name: "CLOSED", value: "b")
        ]
        let agent = DetectedAgent(name: "cursor", confidence: .high, source: "LUNA_AGENT")
        XCTAssertEqual(
            MCPAllowlist.blockedNames(["OPEN", "CLOSED"], secrets: secrets, agent: agent),
            ["CLOSED"]
        )
        let human = DetectedAgent(name: "zsh", confidence: .low, source: "parent-process:zsh")
        XCTAssertEqual(
            MCPAllowlist.blockedNames(["OPEN", "CLOSED"], secrets: secrets, agent: human),
            []
        )
    }

    private func makeService(detector: AgentDetecting) throws -> VaultService {
        let dbURL = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("mcp-read-\(UUID().uuidString).db")
        addTeardownBlock { try? FileManager.default.removeItem(at: dbURL) }
        return VaultService(
            store: MemStore(),
            audit: try AuditDB(url: dbURL),
            detector: detector,
            biometric: NoopBiometricGate()
        )
    }
}

private final class MemStore: KeychainStoring, @unchecked Sendable {
    private var items: [String: Secret] = [:]
    func add(_ s: Secret) throws { items[s.name] = s }
    func update(_ s: Secret) throws { items[s.name] = s }
    func read(name: String) throws -> Secret { guard let s = items[name] else { throw SecretError.notFound(name: name) }; return s }
    func delete(name: String) throws { items.removeValue(forKey: name) }
    func list() throws -> [Secret] { Array(items.values) }
    func exists(name: String) throws -> Bool { items[name] != nil }
}
