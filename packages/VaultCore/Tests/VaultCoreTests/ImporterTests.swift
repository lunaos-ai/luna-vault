import XCTest
@testable import VaultCore

final class ImporterTests: XCTestCase {
    func test_dotenv_parses_kv_pairs() {
        let items = DotenvImporter.parse("""
        # leading comment
        DATABASE_URL=postgres://localhost/db
        API_KEY=secret123
        export STRIPE_KEY=sk_test_abc
        QUOTED="value with spaces"
        SINGLE='single quoted'
        EMPTY=
        """)
        let dict = Dictionary(uniqueKeysWithValues: items.map { ($0.name, $0.value) })
        XCTAssertEqual(dict["DATABASE_URL"], "postgres://localhost/db")
        XCTAssertEqual(dict["API_KEY"], "secret123")
        XCTAssertEqual(dict["STRIPE_KEY"], "sk_test_abc")
        XCTAssertEqual(dict["QUOTED"], "value with spaces")
        XCTAssertEqual(dict["SINGLE"], "single quoted")
        XCTAssertNil(dict["EMPTY"])
    }

    func test_dotenv_strips_inline_comments() {
        let items = DotenvImporter.parse("API_KEY=abc # trailing comment")
        XCTAssertEqual(items.first?.value, "abc")
    }

    func test_env_importer_matches_glob() {
        let env = ["CF_API_TOKEN": "tok1", "STRIPE_KEY": "k", "PATH": "/usr/bin", "HOME": "/root"]
        let items = EnvImporter.collect(env: env, matching: ["CF_*", "STRIPE_*"])
        let names = Set(items.map(\.name))
        XCTAssertEqual(names, Set(["CF_API_TOKEN", "STRIPE_KEY"]))
    }

    func test_env_importer_excludes_banned() {
        let env = ["PATH": "/usr/bin", "HOME": "/root", "MY_TOKEN": "v"]
        let items = EnvImporter.collect(env: env, matching: ["*"])
        let names = Set(items.map(\.name))
        XCTAssertTrue(names.contains("MY_TOKEN"))
        XCTAssertFalse(names.contains("PATH"))
        XCTAssertFalse(names.contains("HOME"))
    }

    func test_import_into_service_records_audit() throws {
        let dbURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("imp-\(UUID().uuidString).db")
        defer { try? FileManager.default.removeItem(at: dbURL) }
        let audit = try AuditDB(url: dbURL)
        let service = VaultService(
            store: TestStore(),
            audit: audit,
            detector: StubAgentDetector(),
            biometric: NoopBiometricGate()
        )
        let items = [
            VaultService.ImportItem(name: "A", value: "1"),
            VaultService.ImportItem(name: "B", value: "2")
        ]
        let result = try service.importSecrets(items, overwrite: false)
        XCTAssertEqual(result.imported.sorted(), ["A", "B"])
        let events = try audit.query(AuditFilter())
        XCTAssertEqual(events.filter { $0.action == .importEvent }.count, 2)
    }

    func test_import_skips_existing_when_not_overwrite() throws {
        let dbURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("imp-\(UUID().uuidString).db")
        defer { try? FileManager.default.removeItem(at: dbURL) }
        let store = TestStore()
        try store.add(Secret(name: "EXISTING", value: "old"))
        let service = VaultService(
            store: store,
            audit: try AuditDB(url: dbURL),
            detector: StubAgentDetector(),
            biometric: NoopBiometricGate()
        )
        let result = try service.importSecrets(
            [VaultService.ImportItem(name: "EXISTING", value: "new")],
            overwrite: false
        )
        XCTAssertEqual(result.skipped, ["EXISTING"])
        XCTAssertEqual(try store.read(name: "EXISTING").value, "old")
    }
}

private final class TestStore: KeychainStoring, @unchecked Sendable {
    private var items: [String: Secret] = [:]
    func add(_ s: Secret) throws { if items[s.name] != nil { throw SecretError.duplicate(name: s.name) }; items[s.name] = s }
    func update(_ s: Secret) throws { items[s.name] = s }
    func read(name: String) throws -> Secret { guard let s = items[name] else { throw SecretError.notFound(name: name) }; return s }
    func delete(name: String) throws { items.removeValue(forKey: name) }
    func list() throws -> [Secret] { Array(items.values) }
    func exists(name: String) throws -> Bool { items[name] != nil }
}
