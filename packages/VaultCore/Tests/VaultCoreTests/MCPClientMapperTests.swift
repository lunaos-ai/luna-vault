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
        XCTAssertEqual(MCPClientMapper.canonical(from: "mcp:devin"), "devin")
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

final class MCPBinaryResolverTests: XCTestCase {
    func test_app_helpers_cli_resolves_macos_sibling() {
        let helpersCLI = "/tmp/Fake.app/Contents/Helpers/vibevault"
        let candidates = MCPBinaryResolver.candidates(cliArgument: helpersCLI)
        XCTAssertTrue(candidates.contains("/tmp/Fake.app/Contents/MacOS/vibevault-mcp"))
        XCTAssertTrue(candidates.contains("/tmp/Fake.app/Contents/Helpers/vibevault-mcp"))
    }
}
