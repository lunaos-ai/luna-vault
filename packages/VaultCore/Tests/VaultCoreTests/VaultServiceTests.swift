import XCTest
@testable import VaultCore

final class VaultServiceTests: XCTestCase {
    private var dbURL: URL!
    private var service: VaultService!
    private var store: InMemoryStore!
    private var audit: AuditDB!

    override func setUpWithError() throws {
        dbURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("svc-\(UUID().uuidString).db")
        store = InMemoryStore()
        audit = try AuditDB(url: dbURL)
        service = VaultService(
            store: store,
            audit: audit,
            detector: StubAgentDetector(DetectedAgent(name: "claude-code", confidence: .high, source: "stub")),
            biometric: NoopBiometricGate(),
            sessionId: "fixed-session"
        )
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: dbURL)
    }

    func test_add_records_write_event() throws {
        try service.add(name: "TOKEN", value: "v")
        let events = try audit.query(AuditFilter())
        XCTAssertEqual(events.count, 1)
        XCTAssertEqual(events[0].action, .write)
        XCTAssertEqual(events[0].agent, "claude-code")
        XCTAssertEqual(events[0].sessionId, "fixed-session")
    }

    func test_read_records_read_event_with_agent() async throws {
        try service.add(name: "TOKEN", value: "secret-v")
        let secret = try await service.read(name: "TOKEN")
        XCTAssertEqual(secret.value, "secret-v")
        let events = try audit.query(AuditFilter())
        XCTAssertEqual(events.map(\.action), [.read, .write])
        XCTAssertEqual(events.first?.action, .read)
    }

    func test_delete_records_delete_event() throws {
        try service.add(name: "X", value: "v")
        try service.delete(name: "X")
        let events = try audit.query(AuditFilter())
        XCTAssertTrue(events.contains { $0.action == .delete })
    }
}

private final class InMemoryStore: KeychainStoring, @unchecked Sendable {
    private var items: [String: Secret] = [:]
    func add(_ s: Secret) throws { if items[s.name] != nil { throw SecretError.duplicate(name: s.name) }; items[s.name] = s }
    func update(_ s: Secret) throws { guard items[s.name] != nil else { throw SecretError.notFound(name: s.name) }; items[s.name] = s }
    func read(name: String) throws -> Secret { guard let s = items[name] else { throw SecretError.notFound(name: name) }; return s }
    func delete(name: String) throws { guard items.removeValue(forKey: name) != nil else { throw SecretError.notFound(name: name) } }
    func list() throws -> [Secret] { Array(items.values) }
    func exists(name: String) throws -> Bool { items[name] != nil }
}
