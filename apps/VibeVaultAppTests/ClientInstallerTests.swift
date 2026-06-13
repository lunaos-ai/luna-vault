import XCTest
@testable import VibeVaultApp

/// Exercises the URL-injectable installer core against a temp config file so the
/// user's real MCP client configs are never touched.
final class ClientInstallerTests: XCTestCase {
    private var dir: URL!
    private var config: URL!

    override func setUpWithError() throws {
        dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("mcp-test-\(UUID().uuidString)")
        config = dir.appendingPathComponent("nested/mcp.json")
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: dir)
    }

    func test_status_whenConfigMissing_reportsNotInstalled() {
        let s = MCPClientInstaller.status(at: config, kind: .cursor)
        XCTAssertFalse(s.configExists)
        XCTAssertFalse(s.installed)
        XCTAssertFalse(s.parentDirExists)
    }

    func test_install_createsParentAndWritesServer() throws {
        try MCPClientInstaller.install(at: config, binaryPath: "/usr/local/bin/vibevault-mcp")
        let s = MCPClientInstaller.status(at: config, kind: .cursor)
        XCTAssertTrue(s.configExists)
        XCTAssertTrue(s.installed)
        let json = try JSONSerialization.jsonObject(with: Data(contentsOf: config)) as? [String: Any]
        let servers = json?["mcpServers"] as? [String: Any]
        let entry = servers?[MCPClientInstaller.serverKey] as? [String: Any]
        XCTAssertEqual(entry?["command"] as? String, "/usr/local/bin/vibevault-mcp")
    }

    func test_install_preservesExistingServersAndUsesServersKey() throws {
        let existing = ["servers": ["other": ["command": "x"]]]
        try FileManager.default.createDirectory(
            at: config.deletingLastPathComponent(), withIntermediateDirectories: true)
        try JSONSerialization.data(withJSONObject: existing).write(to: config)

        try MCPClientInstaller.install(at: config, binaryPath: "/bin/vv")
        let json = try JSONSerialization.jsonObject(with: Data(contentsOf: config)) as? [String: Any]
        let servers = json?["servers"] as? [String: Any]
        XCTAssertNotNil(servers?["other"], "existing server must survive")
        XCTAssertNotNil(servers?[MCPClientInstaller.serverKey])
        XCTAssertNil(json?["mcpServers"], "must reuse the existing servers key, not add mcpServers")
    }

    func test_uninstall_removesOnlyOurServer() throws {
        try MCPClientInstaller.install(at: config, binaryPath: "/bin/vv")
        try MCPClientInstaller.uninstall(at: config)
        let s = MCPClientInstaller.status(at: config, kind: .cursor)
        XCTAssertTrue(s.configExists)
        XCTAssertFalse(s.installed)
    }

    func test_uninstall_missingConfig_isNoOp() throws {
        XCTAssertNoThrow(try MCPClientInstaller.uninstall(at: config))
    }

    func test_kind_metadata_isStable() {
        XCTAssertEqual(MCPClientKind.claudeCode.rawValue, "claude-code")
        XCTAssertTrue(MCPClientKind.claudeDesktop.configURL.path.contains("claude_desktop_config.json"))
        for k in MCPClientKind.allCases {
            XCTAssertFalse(k.displayName.isEmpty)
            XCTAssertFalse(k.docsHint.isEmpty)
        }
    }
}
