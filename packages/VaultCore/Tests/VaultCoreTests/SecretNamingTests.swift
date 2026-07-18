import XCTest
@testable import VaultCore

final class SecretNamingTests: XCTestCase {
    func test_default_project_prefix_from_folder() {
        let url = URL(fileURLWithPath: "/Users/dev/my-worker")
        XCTAssertEqual(SecretNaming.defaultProjectPrefix(from: url), "MY_WORKER_")
    }

    func test_apply_prefix_adds_underscore() {
        XCTAssertEqual(
            SecretNaming.applyPrefix("MYAPP", to: "CF_API_TOKEN"),
            "MYAPP_CF_API_TOKEN"
        )
    }

    func test_apply_prefix_keeps_trailing_underscore() {
        XCTAssertEqual(
            SecretNaming.applyPrefix("MYAPP_", to: "CF_API_TOKEN"),
            "MYAPP_CF_API_TOKEN"
        )
    }

    func test_empty_prefix_returns_original_name() {
        XCTAssertEqual(SecretNaming.applyPrefix("", to: "CF_API_TOKEN"), "CF_API_TOKEN")
    }

    func test_project_import_applies_prefix() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("vv-prefix-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        try "CF_API_TOKEN=real-token-value\n".write(
            to: root.appendingPathComponent(".env"),
            atomically: true,
            encoding: .utf8
        )
        let result = ProjectMissingImporter.collect(
            projectURL: root,
            missing: ["CF_API_TOKEN"],
            prefix: "MYWORKER_"
        )
        XCTAssertEqual(result.items.count, 1)
        XCTAssertEqual(result.items[0].name, "MYWORKER_CF_API_TOKEN")
        XCTAssertEqual(result.previews[0].vaultName, "MYWORKER_CF_API_TOKEN")
    }
}
