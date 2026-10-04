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

    func test_read_cache_invalidated_on_delete() async throws {
        try service.add(name: "CACHED", value: "old")
        _ = try await service.read(name: "CACHED")
        try service.delete(name: "CACHED")
        do {
            _ = try await service.read(name: "CACHED")
            XCTFail("expected notFound after delete")
        } catch SecretError.notFound {
            // expected
        } catch {
            XCTFail("unexpected \(error)")
        }
    }

    func test_read_cache_invalidated_on_update() async throws {
        try service.add(name: "CACHED", value: "old")
        _ = try await service.read(name: "CACHED")
        try service.update(name: "CACHED", value: "new")
        let secret = try await service.read(name: "CACHED")
        XCTAssertEqual(secret.value, "new")
    }

    func test_update_preserves_creation_date() throws {
        let createdAt = Date(timeIntervalSince1970: 1_700_000_000)
        try service.add(name: "CREATED", value: "old", createdAt: createdAt)
        try service.update(name: "CREATED", value: "new")
        let secret = try store.read(name: "CREATED")
        XCTAssertEqual(secret.createdAt, createdAt)
        XCTAssertGreaterThanOrEqual(secret.updatedAt, createdAt)
    }

    func test_add_and_update_accept_sync_timestamps() throws {
        let createdAt = Date(timeIntervalSince1970: 1_700_000_000)
        let addedAt = Date(timeIntervalSince1970: 1_700_000_100)
        let updatedAt = Date(timeIntervalSince1970: 1_700_000_200)

        try service.add(
            name: "SYNCED",
            value: "old",
            createdAt: createdAt,
            updatedAt: addedAt
        )
        XCTAssertEqual(try store.read(name: "SYNCED").updatedAt, addedAt)

        try service.update(
            name: "SYNCED",
            value: "new",
            createdAt: createdAt,
            updatedAt: updatedAt
        )
        let secret = try store.read(name: "SYNCED")
        XCTAssertEqual(secret.createdAt, createdAt)
        XCTAssertEqual(secret.updatedAt, updatedAt)
    }

    func test_duplicate_copies_value_under_copy_name() async throws {
        try service.add(
            name: "TOKEN",
            value: "secret-v",
            notes: "prod",
            mcpAllowed: true
        )
        let copyName = try await service.duplicate(name: "TOKEN")
        XCTAssertEqual(copyName, "TOKEN-copy")
        let copy = try store.read(name: "TOKEN-copy")
        XCTAssertEqual(copy.value, "secret-v")
        XCTAssertEqual(copy.notes, "prod")
        XCTAssertFalse(copy.mcpAllowed)
        XCTAssertEqual(try store.read(name: "TOKEN").value, "secret-v")
    }

    func test_duplicate_increments_when_copy_exists() async throws {
        try service.add(name: "TOKEN", value: "v")
        try service.add(name: "TOKEN-copy", value: "other")
        let copyName = try await service.duplicate(name: "TOKEN")
        XCTAssertEqual(copyName, "TOKEN-copy-2")
        XCTAssertEqual(try store.read(name: "TOKEN-copy-2").value, "v")
    }

    func test_add_json_pretty_prints_and_rejects_invalid() throws {
        try service.add(name: "SA", value: #"{"b":2,"a":1}"#, valueKind: .json)
        let stored = try store.read(name: "SA")
        XCTAssertEqual(stored.valueKind, .json)
        XCTAssertEqual(stored.value, try SecretJSON.prettyPrinted(#"{"a":1,"b":2}"#))

        XCTAssertThrowsError(try service.add(name: "BAD", value: "{nope", valueKind: .json)) { error in
            XCTAssertEqual(error as? SecretError, .invalidJSON("malformed"))
        }
    }

    func test_mcp_toggle_preserves_json_kind() async throws {
        try service.add(name: "SA", value: #"{"k":"v"}"#, valueKind: .json)
        try await service.setMCPAllowed(name: "SA", allowed: true)
        let stored = try store.read(name: "SA")
        XCTAssertEqual(stored.valueKind, .json)
        XCTAssertTrue(stored.mcpAllowed)
        XCTAssertTrue(stored.value.contains("\"k\""))
    }

    func test_duplicate_preserves_json_kind() async throws {
        try service.add(name: "SA", value: #"{"k":"v"}"#, mcpAllowed: true, valueKind: .json)
        let copyName = try await service.duplicate(name: "SA")
        let copy = try store.read(name: copyName)
        XCTAssertEqual(copy.valueKind, .json)
        XCTAssertFalse(copy.mcpAllowed)
    }

    func test_updateValue_switches_text_to_json() async throws {
        try service.add(name: "SA", value: #"{"k":"v"}"#)
        try await service.updateValue(name: "SA", value: #"{"k":"v"}"#, valueKind: .json)
        let stored = try store.read(name: "SA")
        XCTAssertEqual(stored.valueKind, .json)
        XCTAssertEqual(stored.value, try SecretJSON.prettyPrinted(#"{"k":"v"}"#))
    }

    func test_rotate_json_revalidates() async throws {
        try service.add(name: "SA", value: #"{"k":"old"}"#, valueKind: .json)
        try await service.rotate(name: "SA", newValue: #"{"k":"new"}"#)
        XCTAssertEqual(try store.read(name: "SA").valueKind, .json)
        XCTAssertTrue(try store.read(name: "SA").value.contains("new"))
        do {
            try await service.rotate(name: "SA", newValue: "not-json")
            XCTFail("expected invalidJSON")
        } catch SecretError.invalidJSON {
            // expected
        }
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
