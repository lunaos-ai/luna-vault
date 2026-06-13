import XCTest
@testable import VaultCore

final class GitGuardTests: XCTestCase {
    private func tempProject() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("gg-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    func testEnsureGitignoreAddsThenIsIdempotent() throws {
        let project = try tempProject()
        defer { try? FileManager.default.removeItem(at: project) }

        XCTAssertTrue(try GitGuard.ensureGitignore(projectURL: project))
        let text = try String(contentsOf: project.appendingPathComponent(".gitignore"), encoding: .utf8)
        XCTAssertTrue(text.contains(".env"))
        XCTAssertTrue(text.contains(".env.local"))
        XCTAssertTrue(text.contains(GitGuard.marker))

        XCTAssertFalse(try GitGuard.ensureGitignore(projectURL: project))  // no change second time
    }

    func testEnsureGitignorePreservesExisting() throws {
        let project = try tempProject()
        defer { try? FileManager.default.removeItem(at: project) }
        let gi = project.appendingPathComponent(".gitignore")
        try "node_modules\n.env\n".write(to: gi, atomically: true, encoding: .utf8)

        XCTAssertTrue(try GitGuard.ensureGitignore(projectURL: project))  // adds .env.local
        let text = try String(contentsOf: gi, encoding: .utf8)
        XCTAssertTrue(text.contains("node_modules"))
        XCTAssertEqual(text.components(separatedBy: ".env.local").count - 1, 1)
    }

    func testHookScriptHasMarkerAndPatternsButNoSecrets() {
        let script = GitGuard.precommitHookScript()
        XCTAssertTrue(script.contains(GitGuard.marker))
        XCTAssertTrue(script.contains("AKIA"))
        XCTAssertTrue(script.contains("PRIVATE KEY"))
        XCTAssertTrue(script.hasPrefix("#!/usr/bin/env bash"))
    }

    func testInstallHookStatesAndExecutableBit() throws {
        let project = try tempProject()
        defer { try? FileManager.default.removeItem(at: project) }
        try FileManager.default.createDirectory(
            at: project.appendingPathComponent(".git"), withIntermediateDirectories: true)

        XCTAssertEqual(try GitGuard.installPrecommitHook(projectURL: project), .installed)
        XCTAssertEqual(try GitGuard.installPrecommitHook(projectURL: project), .alreadyInstalled)

        let hook = project.appendingPathComponent(".git/hooks/pre-commit")
        let perms = try FileManager.default.attributesOfItem(atPath: hook.path)[.posixPermissions] as? NSNumber
        XCTAssertEqual(perms?.int16Value, 0o755)
    }

    func testInstallHookSkipsForeignHook() throws {
        let project = try tempProject()
        defer { try? FileManager.default.removeItem(at: project) }
        let hooks = project.appendingPathComponent(".git/hooks", isDirectory: true)
        try FileManager.default.createDirectory(at: hooks, withIntermediateDirectories: true)
        try "#!/bin/sh\necho mine\n".write(
            to: hooks.appendingPathComponent("pre-commit"), atomically: true, encoding: .utf8)

        XCTAssertEqual(try GitGuard.installPrecommitHook(projectURL: project), .skippedForeignHook)
    }
}
