import XCTest
@testable import VaultCore

final class MCPClientMapperTests: XCTestCase {
    func test_maps_cursor_client_info() {
        XCTAssertEqual(MCPClientMapper.canonical(from: "Cursor"), "cursor")
        XCTAssertEqual(MCPClientMapper.canonical(from: "mcp:cursor-agent"), "cursor")
    }

    func test_maps_vscode_and_copilot() {
        XCTAssertEqual(MCPClientMapper.canonical(from: "VS Code"), "vscode")
        XCTAssertEqual(MCPClientMapper.canonical(from: "GitHub Copilot"), "vscode")
    }

    func test_maps_devin() {
        XCTAssertEqual(MCPClientMapper.canonical(from: "Devin"), "devin")
    }

    func test_maps_claude_variants() {
        XCTAssertEqual(MCPClientMapper.canonical(from: "Claude Code"), "claude-code")
        XCTAssertEqual(MCPClientMapper.canonical(from: "Claude Desktop"), "claude-desktop")
    }
}

final class MCPClientInstallerTests: XCTestCase {
    func test_agent_env_sets_luna_agent() {
        let env = MCPClientInstaller.agentEnv(for: .cursor)
        XCTAssertEqual(env["LUNA_AGENT"], "cursor")
        XCTAssertFalse(env["LUNA_SESSION"]?.isEmpty ?? true)
    }
}
