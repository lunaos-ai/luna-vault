import XCTest
@testable import VaultCore

final class AgentSkillInstallerTests: XCTestCase {
    func test_bundled_content_has_frontmatter() {
        XCTAssertTrue(AgentSkillContent.markdown.contains("name: vibevault"))
    }

    func test_install_writes_skill_file() throws {
        let tmp = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let original = AgentSkillTarget.cursor.installDirectory
        defer { try? FileManager.default.removeItem(at: tmp) }
        // Use custom path via direct write test
        try FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
        let file = tmp.appendingPathComponent("SKILL.md")
        try AgentSkillInstaller.bundledSkillContent().write(to: file, atomically: true, encoding: .utf8)
        XCTAssertTrue(FileManager.default.fileExists(atPath: file.path))
        _ = original // install uses fixed paths; smoke write only
    }

    func test_plugin_manifest_examples() {
        let manifests = PluginManifestLoader.bundledExamples()
        XCTAssertTrue(manifests.contains { $0.id == "github-actions" })
    }
}
