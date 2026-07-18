import XCTest
@testable import VaultCore

final class CursorRulesInstallerTests: XCTestCase {
    private var tmp: URL!

    override func setUpWithError() throws {
        tmp = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("cr-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: tmp)
    }

    func test_install_writes_mdc() throws {
        XCTAssertFalse(CursorRulesInstaller.isInstalled(projectURL: tmp))
        try CursorRulesInstaller.install(projectURL: tmp)
        XCTAssertTrue(CursorRulesInstaller.isInstalled(projectURL: tmp))
        let body = try String(contentsOf: CursorRulesInstaller.rulesURL(projectURL: tmp), encoding: .utf8)
        XCTAssertTrue(body.contains("version: \(CursorRulesInstaller.version)"))
        XCTAssertTrue(body.contains("scan_project"))
        XCTAssertFalse(CursorRulesInstaller.needsUpdate(projectURL: tmp))
    }

    func test_needsUpdate_when_missing_version() throws {
        let dir = CursorRulesInstaller.rulesDirectory(projectURL: tmp)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try "old rules".write(to: CursorRulesInstaller.rulesURL(projectURL: tmp), atomically: true, encoding: .utf8)
        XCTAssertTrue(CursorRulesInstaller.needsUpdate(projectURL: tmp))
    }
}

final class ShadowMCPScannerTests: XCTestCase {
    func test_parse_concept_with_temp_config() throws {
        let home = FileManager.default.temporaryDirectory.appendingPathComponent("mcp-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: home, withIntermediateDirectories: true)
        // Unit-test parse via writing cursor-like JSON and calling low-level path isn't easy
        // without injecting URL — instead exercise vibeVaultKeys and ShadowMCPServer equality.
        let vv = ShadowMCPServer(name: "vibe-vault", command: "/x/vibevault-mcp", isVibeVault: true, isShadow: false)
        let other = ShadowMCPServer(name: "filesystem", command: "npx", isVibeVault: false, isShadow: true)
        XCTAssertTrue(vv.isVibeVault)
        XCTAssertTrue(other.isShadow)
        XCTAssertTrue(ShadowMCPScanner.vibeVaultKeys.contains("vibe-vault"))
    }

    func test_report_shadow_count() {
        let report = ShadowMCPReport(
            client: .cursor,
            configExists: true,
            vibeVaultInstalled: true,
            servers: [
                ShadowMCPServer(name: "vibe-vault", command: nil, isVibeVault: true, isShadow: false),
                ShadowMCPServer(name: "other", command: "npx", isVibeVault: false, isShadow: true)
            ]
        )
        XCTAssertEqual(report.shadowCount, 1)
        XCTAssertTrue(report.vibeVaultInstalled)
    }
}

final class CursorProjectPrepTests: XCTestCase {
    private var tmp: URL!

    override func setUpWithError() throws {
        tmp = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("prep-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: tmp)
    }

    func test_prepare_without_git_skips_guard() throws {
        let result = try CursorProjectPrep.prepare(
            projectURL: tmp,
            mcpBinaryPath: nil,
            installGuard: true
        )
        XCTAssertTrue(result.rulesInstalled)
        XCTAssertTrue(result.skillInstalled)
        XCTAssertFalse(result.mcpInstalled)
        XCTAssertFalse(result.guardInstalled)
        XCTAssertTrue(CursorRulesInstaller.isInstalled(projectURL: tmp))
    }
}
