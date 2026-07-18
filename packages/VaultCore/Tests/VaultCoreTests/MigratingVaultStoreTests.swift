import XCTest
@testable import VaultCore

final class MigratingVaultStoreTests: XCTestCase {
    private var dir: URL!
    private var primary: EncryptedVaultStore!
    private var legacy: KeychainStore!
    private var store: MigratingVaultStore!

    override func setUpWithError() throws {
        dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("vv-mig-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        primary = EncryptedVaultStore(directory: dir)
        legacy = KeychainStore(service: "dev.vibevault.test.\(UUID().uuidString)", accessGroup: nil)
        store = MigratingVaultStore(primary: primary, legacy: legacy)
    }

    override func tearDownWithError() throws {
        for name in (try? legacy.list().map(\.name)) ?? [] {
            try? legacy.delete(name: name)
        }
        try? FileManager.default.removeItem(at: dir)
    }

    func test_list_returns_file_vault_only() throws {
        try primary.add(Secret(name: "FILE_ONLY", value: "f", mcpAllowed: true))
        try legacy.add(Secret(name: "LEGACY_ONLY", value: "l", mcpAllowed: true))
        let names = Set(try store.list().map(\.name))
        XCTAssertEqual(names, ["FILE_ONLY"])
        XCTAssertTrue(try store.list().first!.mcpAllowed)
    }

    func test_setMCPAllowed_persists_in_file_vault() async throws {
        try store.add(Secret(name: "revenuelens_webhook_secret", value: "v", mcpAllowed: false))
        let dbURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("mig-mcp-\(UUID().uuidString).db")
        defer { try? FileManager.default.removeItem(at: dbURL) }
        let service = VaultService(
            store: store, audit: try AuditDB(url: dbURL),
            detector: StubAgentDetector(), biometric: NoopBiometricGate()
        )
        try await service.setMCPAllowed(name: "revenuelens_webhook_secret", allowed: true)
        let listed = try store.list().first { $0.name == "revenuelens_webhook_secret" }
        XCTAssertEqual(listed?.mcpAllowed, true)
        // Fresh EncryptedVaultStore must see the flag (MCP reads this path).
        let again = EncryptedVaultStore(directory: dir)
        XCTAssertTrue(try again.read(name: "revenuelens_webhook_secret").mcpAllowed)
    }

    func test_pendingLegacyCount_counts_keychain_orphans() throws {
        try legacy.add(Secret(name: "ORPHAN", value: "x"))
        XCTAssertEqual(store.pendingLegacyCount(), 1)
        try primary.add(Secret(name: "ORPHAN", value: "x"))
        XCTAssertEqual(store.pendingLegacyCount(), 0)
    }
}
