import Foundation
import SQLite3

public protocol AuditLogging: Sendable {
    func record(_ event: AuditEvent) throws
    func query(_ filter: AuditFilter) throws -> [AuditEvent]
    func purge(olderThan: Date) throws -> Int
}

public final class AuditDB: AuditLogging, @unchecked Sendable {
    private var db: OpaquePointer?
    private let queue = DispatchQueue(label: "dev.vibevault.audit")
    private let path: String
    private static let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

    public static func defaultURL() -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory())
        let dir = base.appendingPathComponent("vibe-vault", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("audit.db")
    }

    public init(url: URL = AuditDB.defaultURL()) throws {
        self.path = url.path
        guard sqlite3_open(path, &db) == SQLITE_OK else { throw SecretError.keychainStatus(-1) }
        try migrate()
    }

    deinit { sqlite3_close(db) }

    public func record(_ event: AuditEvent) throws {
        try queue.sync {
            let sql = """
                INSERT INTO events (secret_name, agent, agent_confidence, session_id, project_path, action, ts)
                VALUES (?, ?, ?, ?, ?, ?, ?);
            """
            var stmt: OpaquePointer?
            guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { throw SecretError.keychainStatus(-2) }
            defer { sqlite3_finalize(stmt) }
            sqlite3_bind_text(stmt, 1, event.secretName, -1, Self.SQLITE_TRANSIENT)
            sqlite3_bind_text(stmt, 2, event.agent, -1, Self.SQLITE_TRANSIENT)
            sqlite3_bind_text(stmt, 3, event.agentConfidence.rawValue, -1, Self.SQLITE_TRANSIENT)
            sqlite3_bind_text(stmt, 4, event.sessionId, -1, Self.SQLITE_TRANSIENT)
            if let p = event.projectPath { sqlite3_bind_text(stmt, 5, p, -1, Self.SQLITE_TRANSIENT) } else { sqlite3_bind_null(stmt, 5) }
            sqlite3_bind_text(stmt, 6, event.action.rawValue, -1, Self.SQLITE_TRANSIENT)
            sqlite3_bind_double(stmt, 7, event.timestamp.timeIntervalSince1970)
            guard sqlite3_step(stmt) == SQLITE_DONE else { throw SecretError.keychainStatus(-3) }
        }
    }

    public func query(_ filter: AuditFilter) throws -> [AuditEvent] {
        try queue.sync {
            var clauses: [String] = []
            var stringParams: [String] = []
            var doubleParams: [Double] = []
            if let a = filter.agent { clauses.append("agent = ?"); stringParams.append(a) }
            if let s = filter.secretName { clauses.append("secret_name = ?"); stringParams.append(s) }
            if let p = filter.projectPath { clauses.append("project_path = ?"); stringParams.append(p) }
            if let act = filter.action { clauses.append("action = ?"); stringParams.append(act.rawValue) }
            if let since = filter.since { clauses.append("ts >= ?"); doubleParams.append(since.timeIntervalSince1970) }
            var sql = "SELECT id, secret_name, agent, agent_confidence, session_id, project_path, action, ts FROM events"
            if !clauses.isEmpty { sql += " WHERE " + clauses.joined(separator: " AND ") }
            sql += " ORDER BY id DESC LIMIT \(max(1, filter.limit));"
            var stmt: OpaquePointer?
            guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { throw SecretError.keychainStatus(-4) }
            defer { sqlite3_finalize(stmt) }
            var idx: Int32 = 1
            for s in stringParams { sqlite3_bind_text(stmt, idx, s, -1, Self.SQLITE_TRANSIENT); idx += 1 }
            for d in doubleParams { sqlite3_bind_double(stmt, idx, d); idx += 1 }
            var out: [AuditEvent] = []
            while sqlite3_step(stmt) == SQLITE_ROW { out.append(decodeRow(stmt: stmt)) }
            return out
        }
    }

    public func purge(olderThan: Date) throws -> Int {
        try queue.sync {
            var stmt: OpaquePointer?
            guard sqlite3_prepare_v2(db, "DELETE FROM events WHERE ts < ?;", -1, &stmt, nil) == SQLITE_OK else {
                throw SecretError.keychainStatus(-5)
            }
            defer { sqlite3_finalize(stmt) }
            sqlite3_bind_double(stmt, 1, olderThan.timeIntervalSince1970)
            guard sqlite3_step(stmt) == SQLITE_DONE else { throw SecretError.keychainStatus(-6) }
            return Int(sqlite3_changes(db))
        }
    }

    private func decodeRow(stmt: OpaquePointer?) -> AuditEvent {
        let id = sqlite3_column_int64(stmt, 0)
        let secret = String(cString: sqlite3_column_text(stmt, 1))
        let agent = String(cString: sqlite3_column_text(stmt, 2))
        let conf = AgentConfidence(rawValue: String(cString: sqlite3_column_text(stmt, 3))) ?? .low
        let session = String(cString: sqlite3_column_text(stmt, 4))
        let project = sqlite3_column_type(stmt, 5) == SQLITE_NULL ? nil : String(cString: sqlite3_column_text(stmt, 5))
        let action = AuditEvent.Action(rawValue: String(cString: sqlite3_column_text(stmt, 6))) ?? .read
        let ts = Date(timeIntervalSince1970: sqlite3_column_double(stmt, 7))
        return AuditEvent(id: id, secretName: secret, agent: agent, agentConfidence: conf,
                          sessionId: session, projectPath: project, action: action, timestamp: ts)
    }

    private func migrate() throws {
        let sql = """
            CREATE TABLE IF NOT EXISTS events (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                secret_name TEXT NOT NULL,
                agent TEXT NOT NULL,
                agent_confidence TEXT NOT NULL,
                session_id TEXT NOT NULL,
                project_path TEXT,
                action TEXT NOT NULL,
                ts REAL NOT NULL
            );
            CREATE INDEX IF NOT EXISTS idx_events_ts ON events(ts);
            CREATE INDEX IF NOT EXISTS idx_events_agent ON events(agent);
            CREATE INDEX IF NOT EXISTS idx_events_secret ON events(secret_name);
        """
        var err: UnsafeMutablePointer<CChar>?
        let rc = sqlite3_exec(db, sql, nil, nil, &err)
        if rc != SQLITE_OK { sqlite3_free(err); throw SecretError.keychainStatus(-99) }
    }
}
