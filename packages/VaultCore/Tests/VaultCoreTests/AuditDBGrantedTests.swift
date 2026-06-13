import XCTest
import SQLite3
@testable import VaultCore

// Covers branches missed in AuditDB after AuditDBEdgeTests:
//   - record(): granted=false path (line 47 false branch)
//   - query(): filter.granted = true / false (line 62)
//   - decodeRow(): AgentConfidence ?? .low fallback (line 96)
//   - decodeRow(): AuditEvent.Action ?? .read fallback (line 99)

final class AuditDBGrantedTests: XCTestCase {
    private var dbURL: URL!
    private var db: AuditDB!

    override func setUpWithError() throws {
        dbURL = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("audit-granted-\(UUID().uuidString).db")
        db = try AuditDB(url: dbURL)
    }

    override func tearDownWithError() throws {
        db = nil
        try? FileManager.default.removeItem(at: dbURL)
    }

    // MARK: - granted=false recording path (line 47 false branch in record())

    func test_record_denied_event_stores_granted_false() throws {
        let denied = AuditEvent(
            secretName: "SECRET_X",
            agent: "cursor",
            agentConfidence: .medium,
            sessionId: "sess-denied",
            projectPath: nil,
            action: .read,
            granted: false
        )
        try db.record(denied)
        let rows = try db.query(AuditFilter(secretName: "SECRET_X"))
        let row = try XCTUnwrap(rows.first)
        XCTAssertFalse(row.granted, "granted=false must round-trip through record/query")
    }

    func test_record_granted_true_round_trips() throws {
        let granted = AuditEvent(
            secretName: "SECRET_Y",
            agent: "claude-code",
            agentConfidence: .high,
            sessionId: "sess-ok",
            projectPath: nil,
            action: .read,
            granted: true
        )
        try db.record(granted)
        let rows = try db.query(AuditFilter(secretName: "SECRET_Y"))
        let row = try XCTUnwrap(rows.first)
        XCTAssertTrue(row.granted)
    }

    // MARK: - filter.granted (line 62 in query())

    func test_filter_granted_true_returns_only_granted_events() throws {
        try db.record(AuditEvent(
            secretName: "G1", agent: "a", agentConfidence: .low,
            sessionId: "s", projectPath: nil, action: .read, granted: true
        ))
        try db.record(AuditEvent(
            secretName: "G2", agent: "a", agentConfidence: .low,
            sessionId: "s", projectPath: nil, action: .read, granted: false
        ))
        var filter = AuditFilter()
        filter.granted = true
        let rows = try db.query(filter)
        XCTAssertTrue(rows.allSatisfy { $0.granted })
        XCTAssertTrue(rows.contains { $0.secretName == "G1" })
        XCTAssertFalse(rows.contains { $0.secretName == "G2" })
    }

    func test_filter_granted_false_returns_only_denied_events() throws {
        try db.record(AuditEvent(
            secretName: "D1", agent: "a", agentConfidence: .low,
            sessionId: "s", projectPath: nil, action: .read, granted: true
        ))
        try db.record(AuditEvent(
            secretName: "D2", agent: "a", agentConfidence: .low,
            sessionId: "s", projectPath: nil, action: .read, granted: false
        ))
        var filter = AuditFilter()
        filter.granted = false
        let rows = try db.query(filter)
        XCTAssertTrue(rows.allSatisfy { !$0.granted })
        XCTAssertTrue(rows.contains { $0.secretName == "D2" })
        XCTAssertFalse(rows.contains { $0.secretName == "D1" })
    }

    // MARK: - decodeRow: AgentConfidence ?? .low (line 96)

    func test_unknown_agentConfidence_rawValue_falls_back_to_low() throws {
        // Inject a row with a bogus confidence string directly into the SQLite file.
        insertRawRow(secretName: "CONF_BOGUS", agent: "a",
                     agentConfidence: "DEFINITELY_NOT_VALID",
                     sessionId: "s", projectPath: nil,
                     action: "read", granted: 1,
                     ts: Date().timeIntervalSince1970)
        let rows = try db.query(AuditFilter(secretName: "CONF_BOGUS"))
        let row = try XCTUnwrap(rows.first)
        XCTAssertEqual(row.agentConfidence, .low,
                       "Unknown confidence rawValue must fall back to .low")
    }

    // MARK: - decodeRow: AuditEvent.Action ?? .read (line 99)

    func test_unknown_action_rawValue_falls_back_to_read() throws {
        insertRawRow(secretName: "ACT_BOGUS", agent: "a",
                     agentConfidence: "high",
                     sessionId: "s", projectPath: nil,
                     action: "totally_unknown_action", granted: 1,
                     ts: Date().timeIntervalSince1970)
        let rows = try db.query(AuditFilter(secretName: "ACT_BOGUS"))
        let row = try XCTUnwrap(rows.first)
        XCTAssertEqual(row.action, .read,
                       "Unknown action rawValue must fall back to .read")
    }

    // MARK: - decodeRow: granted=0 decoded as false via raw insert

    func test_raw_granted_zero_decoded_as_false() throws {
        insertRawRow(secretName: "RAW_DENIED", agent: "bot",
                     agentConfidence: "low",
                     sessionId: "s", projectPath: "/p",
                     action: "write", granted: 0,
                     ts: Date().timeIntervalSince1970)
        let rows = try db.query(AuditFilter(secretName: "RAW_DENIED"))
        let row = try XCTUnwrap(rows.first)
        XCTAssertFalse(row.granted)
    }

    // MARK: - Helper

    /// Directly inserts a row into the SQLite file at dbURL, bypassing AuditDB,
    /// so we can store arbitrary enum rawValues to exercise decodeRow fallbacks.
    private func insertRawRow(
        secretName: String, agent: String, agentConfidence: String,
        sessionId: String, projectPath: String?,
        action: String, granted: Int32, ts: Double
    ) {
        var rawDB: OpaquePointer?
        guard sqlite3_open(dbURL.path, &rawDB) == SQLITE_OK else {
            XCTFail("Could not open raw DB at \(dbURL.path)")
            return
        }
        defer { sqlite3_close(rawDB) }
        let transient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
        let sql = """
            INSERT INTO events
              (secret_name, agent, agent_confidence, session_id, project_path, action, granted, ts)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?);
        """
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(rawDB, sql, -1, &stmt, nil) == SQLITE_OK else {
            XCTFail("Could not prepare raw insert")
            return
        }
        defer { sqlite3_finalize(stmt) }
        sqlite3_bind_text(stmt, 1, secretName, -1, transient)
        sqlite3_bind_text(stmt, 2, agent, -1, transient)
        sqlite3_bind_text(stmt, 3, agentConfidence, -1, transient)
        sqlite3_bind_text(stmt, 4, sessionId, -1, transient)
        if let p = projectPath {
            sqlite3_bind_text(stmt, 5, p, -1, transient)
        } else {
            sqlite3_bind_null(stmt, 5)
        }
        sqlite3_bind_text(stmt, 6, action, -1, transient)
        sqlite3_bind_int(stmt, 7, granted)
        sqlite3_bind_double(stmt, 8, ts)
        XCTAssertEqual(sqlite3_step(stmt), SQLITE_DONE, "Raw insert failed")
    }
}
