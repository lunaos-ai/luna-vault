import XCTest
@testable import VaultCore

final class AuditDBTests: XCTestCase {
    private var dbURL: URL!
    private var db: AuditDB!

    override func setUpWithError() throws {
        dbURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("audit-\(UUID().uuidString).db")
        db = try AuditDB(url: dbURL)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: dbURL)
    }

    func test_record_then_query_returns_event() throws {
        let event = AuditEvent(
            secretName: "CF_API_TOKEN",
            agent: "claude-code",
            agentConfidence: .high,
            sessionId: "s1",
            projectPath: "/tmp/proj",
            action: .read
        )
        try db.record(event)
        let rows = try db.query(AuditFilter())
        XCTAssertEqual(rows.count, 1)
        XCTAssertEqual(rows[0].agent, "claude-code")
        XCTAssertEqual(rows[0].secretName, "CF_API_TOKEN")
        XCTAssertEqual(rows[0].agentConfidence, .high)
    }

    func test_query_filters_by_agent() throws {
        try db.record(AuditEvent(secretName: "A", agent: "claude-code", agentConfidence: .high, sessionId: "s", projectPath: nil, action: .read))
        try db.record(AuditEvent(secretName: "B", agent: "cursor", agentConfidence: .high, sessionId: "s", projectPath: nil, action: .read))
        let rows = try db.query(AuditFilter(agent: "cursor"))
        XCTAssertEqual(rows.count, 1)
        XCTAssertEqual(rows[0].secretName, "B")
    }

    func test_query_filters_by_secret_name() throws {
        try db.record(AuditEvent(secretName: "X", agent: "a", agentConfidence: .low, sessionId: "s", projectPath: nil, action: .read))
        try db.record(AuditEvent(secretName: "Y", agent: "a", agentConfidence: .low, sessionId: "s", projectPath: nil, action: .read))
        let rows = try db.query(AuditFilter(secretName: "X"))
        XCTAssertEqual(rows.map(\.secretName), ["X"])
    }

    func test_purge_removes_old_events() throws {
        let old = AuditEvent(secretName: "OLD", agent: "a", agentConfidence: .low, sessionId: "s", projectPath: nil, action: .read, timestamp: Date(timeIntervalSinceNow: -100))
        let recent = AuditEvent(secretName: "NEW", agent: "a", agentConfidence: .low, sessionId: "s", projectPath: nil, action: .read, timestamp: Date())
        try db.record(old)
        try db.record(recent)
        let deleted = try db.purge(olderThan: Date(timeIntervalSinceNow: -50))
        XCTAssertEqual(deleted, 1)
        let remaining = try db.query(AuditFilter())
        XCTAssertEqual(remaining.map(\.secretName), ["NEW"])
    }

    func test_query_orders_desc_by_id() throws {
        for i in 0..<5 {
            try db.record(AuditEvent(secretName: "S\(i)", agent: "a", agentConfidence: .low, sessionId: "s", projectPath: nil, action: .read))
        }
        let rows = try db.query(AuditFilter(limit: 10))
        XCTAssertEqual(rows.first?.secretName, "S4")
        XCTAssertEqual(rows.last?.secretName, "S0")
    }
}
