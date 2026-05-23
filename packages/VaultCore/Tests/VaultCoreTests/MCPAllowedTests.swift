import XCTest
@testable import VaultCore

final class MCPAllowedTests: XCTestCase {
    func test_secret_defaults_to_mcpAllowed_false() {
        let s = Secret(name: "X", value: "v")
        XCTAssertFalse(s.mcpAllowed)
    }

    func test_keychain_roundtrip_preserves_mcpAllowed_true() throws {
        let store = KeychainStore(service: "dev.vibevault.test.\(UUID().uuidString)")
        let secret = Secret(name: "MCP_ON", value: "v", mcpAllowed: true)
        try store.add(secret)
        let read = try store.read(name: "MCP_ON")
        XCTAssertTrue(read.mcpAllowed)
        try store.delete(name: "MCP_ON")
    }

    func test_keychain_roundtrip_preserves_mcpAllowed_false() throws {
        let store = KeychainStore(service: "dev.vibevault.test.\(UUID().uuidString)")
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
