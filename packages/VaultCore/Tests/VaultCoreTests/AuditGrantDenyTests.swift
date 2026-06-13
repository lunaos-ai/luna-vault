import XCTest
import SQLite3
@testable import VaultCore

final class AuditGrantDenyTests: XCTestCase {
    private func tmpURL() -> URL {
        URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("gd-\(UUID().uuidString).db")
    }

    // MARK: - VaultService grant / deny logging

    func test_read_denied_records_denied_event_and_rethrows() async throws {
        let url = tmpURL(); defer { try? FileManager.default.removeItem(at: url) }
        let store = MemStore(); try store.add(Secret(name: "TOKEN", value: "v"))
        let audit = try AuditDB(url: url)
        let svc = VaultService(
            store: store, audit: audit,
            detector: StubAgentDetector(DetectedAgent(name: "cursor", confidence: .medium, source: "stub")),
            biometric: DenyingGate(), sessionId: "s"
        )
        do {
            _ = try await svc.read(name: "TOKEN")
            XCTFail("expected denial to throw")
        } catch {}
        let events = try audit.query(AuditFilter())
        XCTAssertEqual(events.count, 1)
        XCTAssertEqual(events[0].action, .read)
        XCTAssertFalse(events[0].granted)
        XCTAssertEqual(events[0].agent, "cursor")
    }

    func test_read_granted_records_granted_true() async throws {
        let url = tmpURL(); defer { try? FileManager.default.removeItem(at: url) }
        let store = MemStore(); try store.add(Secret(name: "TOKEN", value: "v"))
        let audit = try AuditDB(url: url)
        let svc = VaultService(
            store: store, audit: audit,
            detector: StubAgentDetector(), biometric: NoopBiometricGate(), sessionId: "s"
        )
        _ = try await svc.read(name: "TOKEN")
        let reads = try audit.query(AuditFilter(action: .read))
        XCTAssertEqual(reads.count, 1)
        XCTAssertTrue(reads[0].granted)
    }

    func test_authReason_names_external_agent() {
        let svc = makeSvc()
        let ext = DetectedAgent(name: "claude-code", confidence: .high, source: "x")
        XCTAssertEqual(svc.authReason(for: "API_KEY", agent: ext, fallback: "Reveal"),
                       "allow claude-code to read API_KEY")
    }

    func test_authReason_falls_back_for_local_or_unknown() {
        let svc = makeSvc()
        let unknown = DetectedAgent(name: "unknown", confidence: .low, source: "x")
        XCTAssertEqual(svc.authReason(for: "API_KEY", agent: unknown, fallback: "Reveal X"), "Reveal X")
        let lowNamed = DetectedAgent(name: "bash", confidence: .low, source: "x")
        XCTAssertEqual(svc.authReason(for: "API_KEY", agent: lowNamed, fallback: "Reveal X"), "Reveal X")
    }

    // MARK: - AuditDB granted filter + migration

    func test_granted_filter_separates_allow_and_deny() throws {
        let url = tmpURL(); defer { try? FileManager.default.removeItem(at: url) }
        let db = try AuditDB(url: url)
        try db.record(event(secret: "A", granted: true))
        try db.record(event(secret: "B", granted: false))
        XCTAssertEqual(try db.query(AuditFilter(granted: false)).map(\.secretName), ["B"])
        XCTAssertEqual(try db.query(AuditFilter(granted: true)).map(\.secretName), ["A"])
        XCTAssertEqual(try db.query(AuditFilter()).count, 2)
    }

    func test_legacy_db_without_granted_is_migrated() throws {
        let url = tmpURL(); defer { try? FileManager.default.removeItem(at: url) }
        // Craft the pre-`granted` schema directly.
        var raw: OpaquePointer?
        XCTAssertEqual(sqlite3_open(url.path, &raw), SQLITE_OK)
        let old = """
            CREATE TABLE events (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                secret_name TEXT NOT NULL, agent TEXT NOT NULL,
                agent_confidence TEXT NOT NULL, session_id TEXT NOT NULL,
                project_path TEXT, action TEXT NOT NULL, ts REAL NOT NULL
            );
        """
        XCTAssertEqual(sqlite3_exec(raw, old, nil, nil, nil), SQLITE_OK)
        sqlite3_close(raw)

        // Opening through AuditDB must ALTER in the granted column.
        let db = try AuditDB(url: url)
        try db.record(event(secret: "A", granted: false))
        let events = try db.query(AuditFilter())
        XCTAssertEqual(events.count, 1)
        XCTAssertFalse(events[0].granted)
    }

    // MARK: - helpers

    private func event(secret: String, granted: Bool) -> AuditEvent {
        AuditEvent(secretName: secret, agent: "x", agentConfidence: .high,
                   sessionId: "s", projectPath: nil, action: .read, granted: granted)
    }

    private func makeSvc() -> VaultService {
        VaultService(store: MemStore(), audit: NoAudit(),
                     detector: StubAgentDetector(), biometric: NoopBiometricGate(), sessionId: "s")
    }
}

private final class MemStore: KeychainStoring, @unchecked Sendable {
    private var items: [String: Secret] = [:]
    func add(_ s: Secret) throws { if items[s.name] != nil { throw SecretError.duplicate(name: s.name) }; items[s.name] = s }
    func update(_ s: Secret) throws { guard items[s.name] != nil else { throw SecretError.notFound(name: s.name) }; items[s.name] = s }
    func read(name: String) throws -> Secret { guard let s = items[name] else { throw SecretError.notFound(name: name) }; return s }
    func delete(name: String) throws { guard items.removeValue(forKey: name) != nil else { throw SecretError.notFound(name: name) } }
    func list() throws -> [Secret] { Array(items.values) }
    func exists(name: String) throws -> Bool { items[name] != nil }
}

private final class DenyingGate: BiometricGating, @unchecked Sendable {
    func authenticate(reason: String) async throws { throw SecretError.biometricDenied }
    func resetSession() {}
    func setSessionWindow(_ seconds: TimeInterval) {}
    func sessionWindowSeconds() -> TimeInterval { 0 }
}

private final class NoAudit: AuditLogging, @unchecked Sendable {
    func record(_ event: AuditEvent) throws {}
    func query(_ filter: AuditFilter) throws -> [AuditEvent] { [] }
    func purge(olderThan: Date) throws -> Int { 0 }
}
