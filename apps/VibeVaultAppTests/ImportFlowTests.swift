import AppKit
import XCTest
@testable import VibeVaultApp
@testable import VaultCore

@MainActor
final class ImportFlowTests: XCTestCase {
    private func makeEnv() -> AppEnvironment { Smoke.env(secrets: []) }

    func test_importDotenv_importsItems() throws {
        let env = makeEnv()
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(UUID().uuidString).env")
        try "FOO=bar\nBAZ=qux\n# comment\n".write(to: url, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: url) }

        env.importDotenv(at: url, overwrite: false)
        XCTAssertEqual(Set(env.secrets.map(\.name)), ["FOO", "BAZ"])
        XCTAssertTrue(env.importStatus?.contains("Imported 2") ?? false)
    }

    func test_importDotenv_missingFile_setsError() {
        let env = makeEnv()
        env.importDotenv(at: URL(fileURLWithPath: "/nope/missing.env"), overwrite: false)
        XCTAssertTrue(env.importStatus?.hasPrefix("error:") ?? false)
    }

    func test_importMissing_pullsValuesFromProjectDotenv() throws {
        let env = makeEnv()
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("proj-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try "DATABASE_URL=postgres://x\n".write(
            to: dir.appendingPathComponent(".env"), atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: dir) }

        env.importMissing(projectURL: dir, missing: ["DATABASE_URL"], overwrite: false)
        XCTAssertTrue(env.secrets.contains { $0.name == "DATABASE_URL" })
    }

    func test_importMissing_emptySet_reportsNothingMissing() {
        let env = makeEnv()
        env.importMissing(projectURL: FileManager.default.temporaryDirectory,
                          missing: [], overwrite: false)
        XCTAssertEqual(env.importStatus, "No missing secrets.")
    }

    func test_importMissing_noValueFound_reportsStillMissing() {
        let env = makeEnv()
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("empty-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        env.importMissing(projectURL: dir, missing: ["NOPE"], overwrite: false)
        XCTAssertTrue(env.importStatus?.contains("No .env values") ?? false)
    }

    func test_importClipboard_readsDotenvShapedText() {
        let env = makeEnv()
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString("CLIP_KEY=clipval\n", forType: .string)
        env.importClipboard(overwrite: false)
        XCTAssertTrue(env.secrets.contains { $0.name == "CLIP_KEY" })
    }

    func test_importClipboard_emptyClipboard_reportsNothing() {
        let env = makeEnv()
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString("not dotenv shaped", forType: .string)
        env.importClipboard(overwrite: false)
        XCTAssertTrue(env.importStatus?.contains("nothing dotenv-shaped") ?? false)
    }
}
