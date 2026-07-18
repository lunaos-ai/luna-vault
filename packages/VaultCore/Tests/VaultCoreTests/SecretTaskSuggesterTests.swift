import XCTest
@testable import VaultCore

final class SecretTaskSuggesterTests: XCTestCase {
    func test_suggest_matches_domain_tokens() {
        let scan = ScanResult(
            required: ["STRIPE_KEY", "DATABASE_URL", "CF_API_TOKEN"],
            missing: ["STRIPE_KEY"],
            extra: [],
            sources: [:]
        )
        let result = SecretTaskSuggester.suggest(
            task: "wire stripe billing and database",
            scan: scan,
            vaultNames: ["DATABASE_URL"]
        )
        XCTAssertTrue(result.likely.contains("STRIPE_KEY"))
        XCTAssertTrue(result.likely.contains("DATABASE_URL"))
        XCTAssertTrue(result.missingFromVault.contains("STRIPE_KEY"))
        XCTAssertTrue(result.presentInVault.contains("DATABASE_URL"))
    }

    func test_gitignore_assistant_idempotent() throws {
        let tmp = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("gi-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tmp) }
        XCTAssertTrue(try ProjectIgnoreAssistant.ensureGitignore(projectURL: tmp))
        XCTAssertFalse(try ProjectIgnoreAssistant.ensureGitignore(projectURL: tmp))
        let body = try String(contentsOf: tmp.appendingPathComponent(".gitignore"), encoding: .utf8)
        XCTAssertTrue(body.contains(".env"))
        XCTAssertTrue(try ProjectIgnoreAssistant.ensureCursorignore(projectURL: tmp))
    }

    func test_agents_md_install() throws {
        let tmp = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("ag-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tmp) }
        let scan = ScanResult(required: ["API_KEY"], missing: ["API_KEY"], extra: [], sources: [:])
        _ = try AgentsMarkdownGenerator.install(projectURL: tmp, scan: scan)
        let body = try String(contentsOf: tmp.appendingPathComponent("AGENTS.md"), encoding: .utf8)
        XCTAssertTrue(body.contains("API_KEY"))
        XCTAssertTrue(body.contains(AgentsMarkdownGenerator.marker))
        _ = try AgentsMarkdownGenerator.install(projectURL: tmp, scan: scan)
        let again = try String(contentsOf: tmp.appendingPathComponent("AGENTS.md"), encoding: .utf8)
        XCTAssertEqual(again.components(separatedBy: AgentsMarkdownGenerator.marker).count - 1, 1)
    }
}
