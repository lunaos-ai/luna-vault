import XCTest
@testable import VaultCore

final class AgentDetectorTests: XCTestCase {
    func test_env_override_returns_high_confidence() {
        let det = AgentDetector(
            env: ["LUNA_AGENT": "claude-code"],
            parentProcessLookup: { nil },
            ancestorProcessLookup: { [] }
        )
        let agent = det.detect()
        XCTAssertEqual(agent.name, "claude-code")
        XCTAssertEqual(agent.confidence, .high)
        XCTAssertEqual(agent.source, "LUNA_AGENT")
    }

    func test_known_parent_process_returns_medium() {
        let det = AgentDetector(
            env: [:],
            parentProcessLookup: { "/usr/local/bin/cursor-agent" },
            ancestorProcessLookup: { [] }
        )
        let agent = det.detect()
        XCTAssertEqual(agent.name, "cursor")
        XCTAssertEqual(agent.confidence, .medium)
    }

    func test_devin_parent_process_maps() {
        let det = AgentDetector(
            env: [:],
            parentProcessLookup: { "/Applications/Devin.app/Contents/MacOS/devin" },
            ancestorProcessLookup: { [] }
        )
        let agent = det.detect()
        XCTAssertEqual(agent.name, "devin")
        XCTAssertEqual(agent.confidence, .medium)
    }

    func test_unknown_parent_returns_low() {
        let det = AgentDetector(
            env: [:],
            parentProcessLookup: { "/bin/some-random-shell" },
            ancestorProcessLookup: { [] }
        )
        let agent = det.detect()
        XCTAssertEqual(agent.confidence, .low)
        XCTAssertEqual(agent.name, "some-random-shell")
    }

    func test_no_parent_returns_unknown() {
        let det = AgentDetector(
            env: [:],
            parentProcessLookup: { nil },
            ancestorProcessLookup: { [] }
        )
        let agent = det.detect()
        XCTAssertEqual(agent.name, "unknown")
        XCTAssertEqual(agent.confidence, .low)
    }

    func test_empty_LUNA_AGENT_does_not_match() {
        let det = AgentDetector(
            env: ["LUNA_AGENT": ""],
            parentProcessLookup: { "/usr/local/bin/claude" },
            ancestorProcessLookup: { [] }
        )
        let agent = det.detect()
        XCTAssertEqual(agent.name, "claude-code")
        XCTAssertEqual(agent.confidence, .medium)
    }

    func test_requiresMCPAllowlist_for_luna_agent_and_mcp() {
        XCTAssertTrue(
            DetectedAgent(name: "cursor", confidence: .high, source: "LUNA_AGENT")
                .requiresMCPAllowlist
        )
        XCTAssertTrue(
            DetectedAgent(name: "cursor", confidence: .high, source: "mcp-initialize")
                .requiresMCPAllowlist
        )
        XCTAssertTrue(
            DetectedAgent(name: "cursor", confidence: .medium, source: "parent-process:cursor-agent")
                .requiresMCPAllowlist
        )
        XCTAssertFalse(
            DetectedAgent(name: "claude-code", confidence: .high, source: "stub")
                .requiresMCPAllowlist
        )
        XCTAssertFalse(
            DetectedAgent(name: "zsh", confidence: .low, source: "parent-process:zsh")
                .requiresMCPAllowlist
        )
        XCTAssertFalse(
            DetectedAgent(name: "node", confidence: .medium, source: "parent-process:node")
                .requiresMCPAllowlist
        )
    }

    func test_claudecode_env_is_high_confidence_agent() {
        let det = AgentDetector(
            env: ["CLAUDECODE": "1"],
            parentProcessLookup: { "/bin/zsh" },
            ancestorProcessLookup: { [] }
        )
        let agent = det.detect()
        XCTAssertEqual(agent.name, "claude-code")
        XCTAssertEqual(agent.confidence, .high)
        XCTAssertEqual(agent.source, "env:CLAUDECODE")
        XCTAssertTrue(agent.requiresMCPAllowlist)
    }

    func test_ancestor_cursor_agent_enforces_allowlist() {
        let det = AgentDetector(
            env: [:],
            parentProcessLookup: { "/bin/zsh" },
            ancestorProcessLookup: { ["/usr/local/bin/cursor-agent"] }
        )
        let agent = det.detect()
        XCTAssertEqual(agent.name, "cursor")
        XCTAssertEqual(agent.source, "ancestor:cursor-agent")
        XCTAssertTrue(agent.requiresMCPAllowlist)
    }

    func test_cursor_gui_ancestor_does_not_enforce_allowlist() {
        let det = AgentDetector(
            env: [:],
            parentProcessLookup: { "/bin/zsh" },
            ancestorProcessLookup: { ["/Applications/Cursor.app/Contents/MacOS/Cursor"] }
        )
        let agent = det.detect()
        XCTAssertFalse(agent.requiresMCPAllowlist)
    }
}
