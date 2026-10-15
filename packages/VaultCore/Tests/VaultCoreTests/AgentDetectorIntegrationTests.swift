import XCTest
@testable import VaultCore

final class AgentDetectorIntegrationTests: XCTestCase {
    func test_codex_environment_enforces_both_allowlists() {
        let agent = AgentDetector(
            env: ["CODEX_THREAD_ID": "synthetic-thread"],
            parentProcessLookup: { "/bin/zsh" },
            ancestorProcessLookup: { [] }
        ).detect()

        XCTAssertEqual(agent.name, "codex")
        XCTAssertEqual(agent.source, "env:CODEX_THREAD_ID")
        XCTAssertTrue(agent.requiresMCPAllowlist)
        XCTAssertTrue(agent.requiresAuthenticatorAllowlist)
    }

    func test_codex_shell_ancestor_enforces_both_allowlists() {
        let agent = AgentDetector(
            env: [:],
            parentProcessLookup: { "/bin/zsh" },
            ancestorProcessLookup: { ["/bin/zsh", "/usr/local/bin/codex"] }
        ).detect()

        XCTAssertEqual(agent.name, "codex")
        XCTAssertEqual(agent.source, "ancestor:codex")
        XCTAssertTrue(agent.requiresMCPAllowlist)
        XCTAssertTrue(agent.requiresAuthenticatorAllowlist)
    }

    func test_codex_windows_executable_enforces_both_allowlists() {
        let agent = AgentDetector(
            env: [:],
            parentProcessLookup: { "codex.exe" },
            ancestorProcessLookup: { [] }
        ).detect()

        XCTAssertEqual(agent.name, "codex")
        XCTAssertEqual(agent.source, "parent-process:codex")
        XCTAssertTrue(agent.requiresMCPAllowlist)
        XCTAssertTrue(agent.requiresAuthenticatorAllowlist)
    }

    func test_human_shell_does_not_require_either_allowlist() {
        let agent = AgentDetector(
            env: [:],
            parentProcessLookup: { "/bin/zsh" },
            ancestorProcessLookup: { ["/usr/bin/Terminal"] }
        ).detect()

        XCTAssertFalse(agent.requiresMCPAllowlist)
        XCTAssertFalse(agent.requiresAuthenticatorAllowlist)
    }
}
