#if os(macOS)
import XCTest
@testable import VaultCore

/// Reproduces: a secret added by the CLI is not shown in the running app until
/// restart. Root cause: the write path (VaultService -> EncryptedVaultStore) does
/// not announce changes and the app only reloads at launch / after its own ops.
/// The fix's cross-process trigger is a DistributedNotification posted on every
/// successful mutation. See docs/bdd/app-refresh-on-external-write.md.
final class VaultChangeNotificationTests: XCTestCase {
    private static let changed = Notification.Name("dev.vibevault.vault-changed")
    private var dir: URL!
    private var service: VaultService!

    override func setUpWithError() throws {
        dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("vv-change-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        service = VaultService(
            store: EncryptedVaultStore(directory: dir), audit: NullAudit(),
            detector: NoDetector(), biometric: BiometricGate(sessionWindow: 0, sharedSessionURL: nil)
        )
    }

    override func tearDownWithError() throws {
        KeychainMasterKey.deleteForTests(account: "vault.master.\(dir.lastPathComponent)")
        try? FileManager.default.removeItem(at: dir)
    }

    private func expectChange(_ label: String, _ mutate: () throws -> Void) throws {
        let posted = expectation(description: label)
        posted.assertForOverFulfill = false
        let token = DistributedNotificationCenter.default().addObserver(
            forName: Self.changed, object: nil, queue: .main
        ) { _ in posted.fulfill() }
        defer { DistributedNotificationCenter.default().removeObserver(token) }
        try mutate()
        wait(for: [posted], timeout: 3)
    }

    func test_add_postsVaultChanged() throws {
        try expectChange("add") { try service.add(name: "PUSHCI_PLATFORM_MCP_STAGING_KEY_1", value: "v") }
    }

    func test_update_postsVaultChanged() throws {
        try service.add(name: "K", value: "v")
        try expectChange("update") { try service.update(name: "K", value: "v2") }
    }

    func test_delete_postsVaultChanged() throws {
        try service.add(name: "K", value: "v")
        try expectChange("delete") { try service.delete(name: "K") }
    }
}

private final class NullAudit: AuditLogging, @unchecked Sendable {
    func record(_ event: AuditEvent) throws {}
    func query(_ filter: AuditFilter) throws -> [AuditEvent] { [] }
    func purge(olderThan: Date) throws -> Int { 0 }
}
private final class NoDetector: AgentDetecting, @unchecked Sendable {
    func detect() -> DetectedAgent { DetectedAgent(name: "test", confidence: .low, source: "test") }
}
#endif
