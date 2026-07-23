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
        XCTAssertTrue(body.contains(AgentsMarkdownGenerator.endMarker))
        XCTAssertTrue(body.contains("prefer Vibe Vault"))
        _ = try AgentsMarkdownGenerator.install(projectURL: tmp, scan: scan)
        let again = try String(contentsOf: tmp.appendingPathComponent("AGENTS.md"), encoding: .utf8)
        XCTAssertEqual(again.components(separatedBy: AgentsMarkdownGenerator.marker).count - 1, 1)
    }

    func test_agent_policy_installer_writes_all_targets() throws {
        let tmp = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("ap-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tmp) }
        let scan = ScanResult(required: ["GEMINI_API_KEY"], missing: ["GEMINI_API_KEY"], extra: [], sources: [:])
        for target in AgentPolicyTarget.allCases {
            let result = try AgentPolicyInstaller.install(projectURL: tmp, target: target, scan: scan)
            XCTAssertTrue(FileManager.default.fileExists(atPath: result.path))
            let status = AgentPolicyInstaller.status(projectURL: tmp, target: target)
            XCTAssertTrue(status.installed)
            XCTAssertFalse(status.needsUpdate)
        }
        let gemini = try String(contentsOf: tmp.appendingPathComponent("GEMINI.md"), encoding: .utf8)
        XCTAssertTrue(gemini.contains("Do not create `.env`"))
        XCTAssertTrue(gemini.contains("vibevault run -- <command>"))
    }

    func test_agent_policy_status_marks_old_policy_outdated() throws {
        let tmp = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("aps-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tmp) }
        try "\(AgentsMarkdownGenerator.marker)\nold".write(
            to: tmp.appendingPathComponent("CLAUDE.md"),
            atomically: true,
            encoding: .utf8
        )
        let status = AgentPolicyInstaller.status(projectURL: tmp, target: .claude)
        XCTAssertTrue(status.installed)
        XCTAssertTrue(status.needsUpdate)
    }
}
