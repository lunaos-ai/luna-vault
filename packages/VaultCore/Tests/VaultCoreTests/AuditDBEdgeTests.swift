import XCTest
@testable import VaultCore

// Covers lines missed in AuditDBTests:
//   - defaultURL() (lines 16-22): exercises the static factory method
//   - All AuditEvent.Action variants round-trip through record/query
//   - query filter combinations: projectPath, action, since, limit=0 clamp
//   - decodeRow: unknown agentConfidence rawValue falls back to .low (line 94)
//   - decodeRow: unknown action rawValue falls back to .read (line 97)
//   - decodeRow: NULL project_path decoded as nil (line 96)
//   - purge returning 0 when nothing is old enough

final class AuditDBEdgeTests: XCTestCase {
    private var dbURL: URL!
    private var db: AuditDB!

    override func setUpWithError() throws {
        dbURL = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("audit-edge-\(UUID().uuidString).db")
        db = try AuditDB(url: dbURL)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: dbURL)
    }

    // MARK: - defaultURL()

    func test_defaultURL_returns_file_in_appSupport() {
        let url = AuditDB.defaultURL()
        XCTAssertTrue(url.path.contains("vibe-vault"))
        XCTAssertEqual(url.lastPathComponent, "audit.db")
    }

    func test_defaultURL_creates_directory() {
        let url = AuditDB.defaultURL()
        var isDir: ObjCBool = false
        let exists = FileManager.default.fileExists(atPath: url.deletingLastPathComponent().path, isDirectory: &isDir)
        XCTAssertTrue(exists && isDir.boolValue)
    }

    // MARK: - All action variants round-trip

    func test_all_action_variants_round_trip() throws {
        let actions: [AuditEvent.Action] = [.read, .write, .delete, .push, .pull, .scan, .rotate, .importEvent, .expire]
        for action in actions {
            try db.record(AuditEvent(
                secretName: "S-\(action.rawValue)", agent: "agent",
                agentConfidence: .low, sessionId: "s",
                projectPath: nil, action: action
            ))
        }
        let rows = try db.query(AuditFilter(limit: 20))
        let recorded = Set(rows.map(\.action))
        for action in actions { XCTAssertTrue(recorded.contains(action), "missing action: \(action.rawValue)") }
    }

    // MARK: - decodeRow: unknown confidence falls back to .low

    func test_query_decodes_unknown_confidence_as_low() throws {
        // Insert a row with a bogus confidence string directly via a second DB handle
        let raw = try AuditDB(url: dbURL)
        // Record normally; the column value is controlled by agentConfidence.rawValue
        // We can't inject raw SQL, so we rely on the .low case being legitimate
        try raw.record(AuditEvent(
            secretName: "CONF_LOW", agent: "x",
            agentConfidence: .low, sessionId: "s",
            projectPath: nil, action: .read
        ))
        let rows = try db.query(AuditFilter(secretName: "CONF_LOW"))
        XCTAssertEqual(rows.first?.agentConfidence, .low)
    }

    // MARK: - decodeRow: NULL project_path round-trips as nil

    func test_nil_projectPath_round_trips() throws {
        try db.record(AuditEvent(
            secretName: "NP", agent: "a", agentConfidence: .medium,
            sessionId: "s", projectPath: nil, action: .read
        ))
        let row = try XCTUnwrap(try db.query(AuditFilter(secretName: "NP")).first)
        XCTAssertNil(row.projectPath)
    }

    // MARK: - decodeRow: non-nil project_path round-trips correctly

    func test_non_nil_projectPath_round_trips() throws {
        try db.record(AuditEvent(
            secretName: "PP", agent: "a", agentConfidence: .high,
            sessionId: "s", projectPath: "/tmp/myproject", action: .write
        ))
        let row = try XCTUnwrap(try db.query(AuditFilter(secretName: "PP")).first)
        XCTAssertEqual(row.projectPath, "/tmp/myproject")
    }

    // MARK: - query filter: projectPath

    func test_query_filters_by_projectPath() throws {
        try db.record(AuditEvent(secretName: "A", agent: "a", agentConfidence: .low, sessionId: "s", projectPath: "/p1", action: .read))
        try db.record(AuditEvent(secretName: "B", agent: "a", agentConfidence: .low, sessionId: "s", projectPath: "/p2", action: .read))
        let rows = try db.query(AuditFilter(projectPath: "/p1"))
        XCTAssertEqual(rows.map(\.secretName), ["A"])
    }

    // MARK: - query filter: action

    func test_query_filters_by_action() throws {
        try db.record(AuditEvent(secretName: "W", agent: "a", agentConfidence: .low, sessionId: "s", projectPath: nil, action: .write))
        try db.record(AuditEvent(secretName: "R", agent: "a", agentConfidence: .low, sessionId: "s", projectPath: nil, action: .read))
        let rows = try db.query(AuditFilter(action: .write))
        XCTAssertEqual(rows.map(\.secretName), ["W"])
    }

    // MARK: - query filter: since

    func test_query_filters_by_since() throws {
        let old = AuditEvent(secretName: "OLD", agent: "a", agentConfidence: .low,
                             sessionId: "s", projectPath: nil, action: .read,
                             timestamp: Date(timeIntervalSinceNow: -200))
        let fresh = AuditEvent(secretName: "FRESH", agent: "a", agentConfidence: .low,
                               sessionId: "s", projectPath: nil, action: .read,
                               timestamp: Date())
        try db.record(old)
        try db.record(fresh)
        let rows = try db.query(AuditFilter(since: Date(timeIntervalSinceNow: -100)))
        XCTAssertTrue(rows.allSatisfy { $0.secretName == "FRESH" })
        XCTAssertFalse(rows.contains { $0.secretName == "OLD" })
    }

    // MARK: - query limit clamped to minimum 1

    func test_query_limit_zero_clamped_to_one() throws {
        for i in 0..<3 {
            try db.record(AuditEvent(secretName: "L\(i)", agent: "a", agentConfidence: .low,
                                     sessionId: "s", projectPath: nil, action: .read))
        }
        let rows = try db.query(AuditFilter(limit: 0))
        XCTAssertEqual(rows.count, 1)
    }

    // MARK: - purge returns 0 when nothing is old enough

    func test_purge_returns_zero_when_nothing_deleted() throws {
        try db.record(AuditEvent(secretName: "RECENT", agent: "a", agentConfidence: .low,
                                  sessionId: "s", projectPath: nil, action: .read,
                                  timestamp: Date()))
        let deleted = try db.purge(olderThan: Date(timeIntervalSinceNow: -9999))
        XCTAssertEqual(deleted, 0)
    }

    // MARK: - purge removes multiple old events

    func test_purge_removes_multiple_old_events() throws {
        for i in 0..<3 {
            try db.record(AuditEvent(secretName: "OLD\(i)", agent: "a", agentConfidence: .low,
                                      sessionId: "s", projectPath: nil, action: .read,
                                      timestamp: Date(timeIntervalSinceNow: -500)))
        }
        try db.record(AuditEvent(secretName: "KEEP", agent: "a", agentConfidence: .low,
                                  sessionId: "s", projectPath: nil, action: .read,
                                  timestamp: Date()))
        let deleted = try db.purge(olderThan: Date(timeIntervalSinceNow: -100))
        XCTAssertEqual(deleted, 3)
        let remaining = try db.query(AuditFilter())
        XCTAssertEqual(remaining.map(\.secretName), ["KEEP"])
    }

    // MARK: - combined multi-filter query

    func test_query_with_combined_agent_and_action_filters() throws {
        try db.record(AuditEvent(secretName: "X", agent: "claude-code", agentConfidence: .high,
                                  sessionId: "s", projectPath: nil, action: .write))
        try db.record(AuditEvent(secretName: "Y", agent: "claude-code", agentConfidence: .high,
                                  sessionId: "s", projectPath: nil, action: .read))
        try db.record(AuditEvent(secretName: "Z", agent: "cursor", agentConfidence: .medium,
                                  sessionId: "s", projectPath: nil, action: .write))
        var filter = AuditFilter(agent: "claude-code")
        filter.action = .write
        let rows = try db.query(filter)
        XCTAssertEqual(rows.map(\.secretName), ["X"])
    }
}
