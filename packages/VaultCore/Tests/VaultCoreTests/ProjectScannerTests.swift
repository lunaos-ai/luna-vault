import XCTest
@testable import VaultCore

final class ProjectScannerTests: XCTestCase {
    private var tmpDir: URL!

    override func setUpWithError() throws {
        tmpDir = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("scan-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tmpDir, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: tmpDir)
    }

    func test_dotenv_example_extracts_names() throws {
        try """
        # comment
        DATABASE_URL=postgres://
        STRIPE_KEY=sk_test_xxx

        EMPTY=
        """.write(to: tmpDir.appendingPathComponent(".env.example"), atomically: true, encoding: .utf8)
        let scanner = ProjectScanner(parsers: [DotenvExampleParser()])
        let result = try scanner.scan(projectURL: tmpDir, knownSecrets: [])
        XCTAssertEqual(result.required, Set(["DATABASE_URL", "STRIPE_KEY", "EMPTY"]))
    }

    func test_scanner_reports_missing_and_extra() throws {
        try "API_TOKEN=\nDB_URL=".write(
            to: tmpDir.appendingPathComponent(".env.example"),
            atomically: true,
            encoding: .utf8
        )
        let scanner = ProjectScanner(parsers: [DotenvExampleParser()])
        let result = try scanner.scan(projectURL: tmpDir, knownSecrets: Set(["DB_URL", "STALE_KEY"]))
        XCTAssertEqual(result.missing, Set(["API_TOKEN"]))
        XCTAssertEqual(result.extra, Set(["STALE_KEY"]))
    }

    func test_wrangler_parser_extracts_vars_section() {
        let content = """
        name = "my-worker"
        compatibility_date = "2026-01-01"

        [vars]
        API_BASE = "https://api.example.com"
        ANALYTICS_TOKEN = "tok"

        [[d1_databases]]
        binding = "DB"
        """
        let names = WranglerParser().parse(content: content)
        XCTAssertTrue(names.contains("API_BASE"))
        XCTAssertTrue(names.contains("ANALYTICS_TOKEN"))
    }

    func test_vercel_parser_extracts_env_and_at_refs() {
        let content = """
        {
          "env": { "DATABASE_URL": "@db-url" },
          "build": { "env": { "SENTRY_DSN": "@sentry-dsn" } }
        }
        """
        let names = Set(VercelParser().parse(content: content))
        XCTAssertTrue(names.contains("DATABASE_URL"))
        XCTAssertTrue(names.contains("SENTRY_DSN"))
        XCTAssertTrue(names.contains("DB_URL"))
    }

    func test_package_json_parser_finds_process_env() {
        let content = """
        {
          "scripts": {
            "dev": "cross-env API_KEY=$API_KEY next dev",
            "build": "node -e 'console.log(process.env.SECRET_KEY)'"
          }
        }
        """
        let names = Set(PackageJsonParser().parse(content: content))
        XCTAssertTrue(names.contains("API_KEY"))
        XCTAssertTrue(names.contains("SECRET_KEY"))
    }

    func test_next_config_parser_finds_env_refs() {
        let content = """
        module.exports = {
          env: {
            CUSTOM_KEY: process.env.CUSTOM_KEY,
            ANOTHER_KEY: 'static'
          }
        };
        """
        let names = Set(NextConfigParser().parse(content: content))
        XCTAssertTrue(names.contains("CUSTOM_KEY"))
        XCTAssertTrue(names.contains("ANOTHER_KEY"))
    }
}
