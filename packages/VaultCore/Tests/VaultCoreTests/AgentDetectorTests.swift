import XCTest
@testable import VaultCore

final class AgentDetectorTests: XCTestCase {
    func test_env_override_returns_high_confidence() {
        let det = AgentDetector(env: ["LUNA_AGENT": "claude-code"], parentProcessLookup: { nil })
        let agent = det.detect()
        XCTAssertEqual(agent.name, "claude-code")
        XCTAssertEqual(agent.confidence, .high)
        XCTAssertEqual(agent.source, "LUNA_AGENT")
    }

    func test_known_parent_process_returns_medium() {
        let det = AgentDetector(env: [:], parentProcessLookup: { "/usr/local/bin/cursor-agent" })
        let agent = det.detect()
        XCTAssertEqual(agent.name, "cursor")
        XCTAssertEqual(agent.confidence, .medium)
    }

    func test_unknown_parent_returns_low() {
        let det = AgentDetector(env: [:], parentProcessLookup: { "/bin/some-random-shell" })
        let agent = det.detect()
        XCTAssertEqual(agent.confidence, .low)
        XCTAssertEqual(agent.name, "some-random-shell")
    }

    func test_no_parent_returns_unknown() {
        let det = AgentDetector(env: [:], parentProcessLookup: { nil })
        let agent = det.detect()
        XCTAssertEqual(agent.name, "unknown")
        XCTAssertEqual(agent.confidence, .low)
    }

    func test_empty_LUNA_AGENT_does_not_match() {
        let det = AgentDetector(env: ["LUNA_AGENT": ""], parentProcessLookup: { "/usr/local/bin/claude" })
        let agent = det.detect()
        XCTAssertEqual(agent.name, "claude-code")
        XCTAssertEqual(agent.confidence, .medium)
    }
}
