import XCTest
@testable import VaultCore

final class ProjectRegistryTests: XCTestCase {
    private var tmpDir: URL!

    override func setUpWithError() throws {
        tmpDir = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("projects-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tmpDir, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: tmpDir)
    }

    func test_upsert_dedupes_and_selects() throws {
        let registry = ProjectRegistry(directory: tmpDir)
        let a = try registry.upsert(url: tmpDir)
        let again = try registry.upsert(url: tmpDir)
        XCTAssertEqual(a.id, again.id)
        XCTAssertEqual(registry.list().count, 1)
        XCTAssertEqual(registry.selectedID, a.id)
    }

    func test_record_scan_persists_counts() throws {
        let registry = ProjectRegistry(directory: tmpDir)
        let record = try registry.upsert(url: tmpDir)
        let result = ScanResult(
            required: ["A", "B"], missing: ["B"], extra: ["Z"],
            sources: [:], gitLeaks: ["/.env"]
        )
        try registry.recordScan(id: record.id, result: result, url: tmpDir)
        let reloaded = ProjectRegistry(directory: tmpDir).list()
        XCTAssertEqual(reloaded.first?.requiredCount, 2)
        XCTAssertEqual(reloaded.first?.missingCount, 1)
        XCTAssertEqual(reloaded.first?.leakCount, 1)
        XCTAssertNotNil(reloaded.first?.lastScannedAt)
    }

    func test_remove_and_relocate() throws {
        let registry = ProjectRegistry(directory: tmpDir)
        let record = try registry.upsert(url: tmpDir)
        let moved = tmpDir.appendingPathComponent("moved", isDirectory: true)
        try FileManager.default.createDirectory(at: moved, withIntermediateDirectories: true)
        let updated = try registry.relocate(id: record.id, to: moved)
        XCTAssertEqual(updated.path, moved.standardizedFileURL.path)
        try registry.remove(id: record.id)
        XCTAssertTrue(registry.list().isEmpty)
    }

    func test_missing_folder_is_access_missing() {
        let gone = tmpDir.appendingPathComponent("gone", isDirectory: true)
        let record = ProjectRecord.make(url: gone)
        XCTAssertEqual(record.access, .missing)
    }

    func test_known_names_expand_prefix() {
        let known = SecretNaming.knownNames(
            vaultNames: ["LUNA_VAULT_CF_TOKEN", "OTHER"],
            prefix: "LUNA_VAULT_"
        )
        XCTAssertTrue(known.contains("CF_TOKEN"))
        XCTAssertTrue(known.contains("LUNA_VAULT_CF_TOKEN"))
        XCTAssertTrue(known.contains("OTHER"))
    }

    func test_scan_throws_when_root_missing() {
        let gone = tmpDir.appendingPathComponent("nope")
        XCTAssertThrowsError(try ProjectScanner().scan(projectURL: gone, knownSecrets: [])) { error in
            guard case ProjectScanError.notFound = error else {
                return XCTFail("expected notFound, got \(error)")
            }
        }
    }

    func test_workflow_remembers_scan() throws {
        try "API_KEY=\n".write(
            to: tmpDir.appendingPathComponent(".env.example"),
            atomically: true, encoding: .utf8
        )
        let registry = ProjectRegistry(directory: tmpDir)
        let result = try ProjectWorkflow.scanAndRemember(
            projectURL: tmpDir,
            vaultNames: ["API_KEY"],
            registry: registry
        )
        XCTAssertTrue(result.missing.isEmpty)
        XCTAssertEqual(registry.list().first?.requiredCount, 1)
    }
}
