import AppKit
import XCTest
@testable import VibeVaultApp
@testable import VaultCore

@MainActor
final class AppEnvironmentTests: XCTestCase {
    private func makeEnv() -> AppEnvironment { Smoke.env(secrets: []) }

    func test_add_then_refresh_listsSecret() {
        let env = makeEnv()
        env.addSecret(name: "TOKEN", value: "abc123", notes: "n")
        XCTAssertEqual(env.secrets.map(\.name), ["TOKEN"])
        XCTAssertNil(env.lastError)
    }

    func test_add_duplicate_setsLastError() {
        let env = makeEnv()
        env.addSecret(name: "DUP", value: "1", notes: nil)
        env.addSecret(name: "DUP", value: "2", notes: nil)
        XCTAssertNotNil(env.lastError)
    }

    func test_delete_removesSecret() {
        let env = makeEnv()
        env.addSecret(name: "GONE", value: "x", notes: nil)
        env.deleteSecret(name: "GONE")
        XCTAssertTrue(env.secrets.isEmpty)
    }

    func test_setMCPAllowed_flipsFlag() async {
        let env = makeEnv()
        env.addSecret(name: "AI", value: "v", notes: nil)
        await env.setMCPAllowed(name: "AI", allowed: true)
        XCTAssertTrue(env.secrets.first?.mcpAllowed ?? false)
    }

    func test_rotate_updatesValue() async {
        let env = makeEnv()
        env.addSecret(name: "ROT", value: "old", notes: nil)
        await env.rotate(name: "ROT", newValue: "new")
        XCTAssertNil(env.lastError)
    }

    func test_testBiometric_unlocksWithNoopGate() async {
        let env = makeEnv()
        await env.testBiometric()
        XCTAssertTrue(env.biometricStatus.contains("Unlocked"))
    }

    func test_resetBiometricSession_setsLockedStatus() {
        let env = makeEnv()
        env.resetBiometricSession()
        XCTAssertTrue(env.biometricStatus.contains("Locked"))
    }

    func test_refreshAudit_doesNotThrow() {
        let env = makeEnv()
        env.refreshAudit()
        XCTAssertEqual(env.auditEvents.count, 0)
    }

    func test_trustSession_togglesStatusCopy() {
        let env = makeEnv()
        env.trustSession = true
        XCTAssertTrue(env.biometricStatus.contains("Trusted"))
        env.trustSession = false
        XCTAssertTrue(env.biometricStatus.contains("Re-prompts"))
    }

    func test_scan_populatesResult() async {
        let env = makeEnv()
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("scan-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try? "API_KEY=x\n".write(to: dir.appendingPathComponent(".env"), atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: dir) }

        env.scan(projectURL: dir)
        for _ in 0..<50 where env.isScanning { try? await Task.sleep(nanoseconds: 20_000_000) }
        XCTAssertFalse(env.isScanning)
        XCTAssertNotNil(env.scanResult)
    }
}
