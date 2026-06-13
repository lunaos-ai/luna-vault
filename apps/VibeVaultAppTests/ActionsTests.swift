import AppKit
import XCTest
@testable import VibeVaultApp
@testable import VaultCore

@MainActor
final class ActionsTests: XCTestCase {
    private func tempProject() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("act-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(
            at: url.appendingPathComponent(".git"), withIntermediateDirectories: true)
        return url
    }

    func test_exportEnv_writesFileAndGuard() async throws {
        let env = Smoke.env()
        let project = try tempProject()
        defer { try? FileManager.default.removeItem(at: project) }
        let file = project.appendingPathComponent(".env")

        let status = await env.exportEnv(to: file, names: ["API_KEY"], mode: .overwrite, addGuard: true)
        let text = try String(contentsOf: file, encoding: .utf8)
        XCTAssertTrue(text.contains("API_KEY=sk-live-abcdef123456"))
        XCTAssertTrue(status.contains("Wrote 1 secret"))
        XCTAssertTrue(FileManager.default.fileExists(
            atPath: project.appendingPathComponent(".gitignore").path))
        XCTAssertTrue(FileManager.default.fileExists(
            atPath: project.appendingPathComponent(".git/hooks/pre-commit").path))
    }

    func test_exportEnv_unknownSecret_setsError() async throws {
        let env = Smoke.env()
        let project = try tempProject()
        defer { try? FileManager.default.removeItem(at: project) }
        let status = await env.exportEnv(
            to: project.appendingPathComponent(".env"), names: ["NOPE"], addGuard: false)
        XCTAssertTrue(status.contains("failed"))
        XCTAssertNotNil(env.lastError)
    }

    func test_rotateSaving_recordsPreviousValue() async {
        let env = Smoke.env(secrets: [])
        env.addSecret(name: "ROT", value: "old", notes: nil)
        await env.rotateSaving(name: "ROT", newValue: "new")
        let versions = env.historyVersions(name: "ROT")
        XCTAssertEqual(versions.first?.value, "old")
    }

    func test_rollback_restoresValueAndKeepsHistory() async {
        let env = Smoke.env(secrets: [])
        env.addSecret(name: "K", value: "v1", notes: nil)
        await env.rotateSaving(name: "K", newValue: "v2")
        let v1 = env.historyVersions(name: "K").first!
        await env.rollback(name: "K", to: v1)
        XCTAssertEqual(env.secrets.first(where: { $0.name == "K" })?.updatedAt != nil, true)
        // current value v2 was pushed before restoring v1
        XCTAssertTrue(env.historyVersions(name: "K").contains { $0.value == "v2" })
    }

    func test_copyToClipboard_putsValueOnPasteboard() async {
        let env = Smoke.env()
        await env.copyToClipboard(name: "API_KEY", clearAfter: 60)
        XCTAssertEqual(NSPasteboard.general.string(forType: .string), "sk-live-abcdef123456")
        XCTAssertTrue(env.biometricStatus.contains("Copied"))
    }
}
