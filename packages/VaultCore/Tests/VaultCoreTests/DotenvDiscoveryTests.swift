import XCTest
@testable import VaultCore

final class DotenvDiscoveryTests: XCTestCase {
    private var root: URL!

    override func setUpWithError() throws {
        root = FileManager.default.temporaryDirectory
            .appendingPathComponent("dotenv-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: root)
    }

    func test_finds_nested_env_local() throws {
        let nested = root.appendingPathComponent("apps/web")
        try FileManager.default.createDirectory(at: nested, withIntermediateDirectories: true)
        try "API_KEY=from-local\n".write(
            to: nested.appendingPathComponent(".env.local"),
            atomically: true,
            encoding: .utf8
        )
        let files = DotenvDiscovery.findFiles(under: root)
        XCTAssertTrue(files.contains { $0.lastPathComponent == ".env.local" })
        XCTAssertEqual(DotenvDiscovery.loadValues(under: root)["API_KEY"], "from-local")
    }

    func test_env_local_overrides_env_in_same_folder() throws {
        try "API_KEY=base\nOTHER=1\n".write(
            to: root.appendingPathComponent(".env"),
            atomically: true,
            encoding: .utf8
        )
        try "API_KEY=override\n".write(
            to: root.appendingPathComponent(".env.local"),
            atomically: true,
            encoding: .utf8
        )
        let values = DotenvDiscovery.loadValues(under: root)
        XCTAssertEqual(values["API_KEY"], "override")
        XCTAssertEqual(values["OTHER"], "1")
    }

    func test_scanner_reads_env_local_names() throws {
        try "STRIPE_KEY=sk_test\n".write(
            to: root.appendingPathComponent(".env.local"),
            atomically: true,
            encoding: .utf8
        )
        let scanner = ProjectScanner(parsers: [DotenvFileParser(filename: ".env.local")])
        let result = try scanner.scan(projectURL: root, knownSecrets: [])
        XCTAssertTrue(result.required.contains("STRIPE_KEY"))
    }

    func test_collect_includes_all_dotenv_keys() throws {
        try "ONLY_IN_ENV=secret\n".write(
            to: root.appendingPathComponent(".env.local"),
            atomically: true,
            encoding: .utf8
        )
        let result = ProjectMissingImporter.collect(
            projectURL: root,
            missing: [],
            includeAllDotenv: true
        )
        XCTAssertEqual(result.previews.map(\.sourceName), ["ONLY_IN_ENV"])
        XCTAssertEqual(result.items.first?.value, "secret")
    }
}
