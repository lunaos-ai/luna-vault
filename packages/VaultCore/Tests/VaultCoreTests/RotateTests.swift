import XCTest
@testable import VaultCore

final class RotateTests: XCTestCase {
    func test_rotate_with_new_value_updates_secret_and_records_audit() async throws {
        let dbURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("rot-\(UUID().uuidString).db")
        defer { try? FileManager.default.removeItem(at: dbURL) }
        let store = MemStore()
        try store.add(Secret(name: "TOKEN", value: "old", rotateEveryDays: 30))
        let audit = try AuditDB(url: dbURL)
        let service = VaultService(
            store: store, audit: audit,
            detector: StubAgentDetector(), biometric: NoopBiometricGate()
        )
        try await service.rotate(name: "TOKEN", newValue: "new")
        let after = try store.read(name: "TOKEN")
        XCTAssertEqual(after.value, "new")
        XCTAssertNotNil(after.lastRotatedAt)
        let events = try audit.query(AuditFilter())
        XCTAssertTrue(events.contains { $0.action == .rotate })
    }

    func test_rotate_mark_only_keeps_value() async throws {
        let dbURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("rot2-\(UUID().uuidString).db")
        defer { try? FileManager.default.removeItem(at: dbURL) }
        let store = MemStore()
        try store.add(Secret(name: "T", value: "kept"))
        let service = VaultService(
            store: store, audit: try AuditDB(url: dbURL),
            detector: StubAgentDetector(), biometric: NoopBiometricGate()
        )
        try await service.rotate(name: "T", newValue: nil)
        XCTAssertEqual(try store.read(name: "T").value, "kept")
        XCTAssertNotNil(try store.read(name: "T").lastRotatedAt)
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
