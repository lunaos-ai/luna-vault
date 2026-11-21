import Combine
import XCTest
import VaultCore
@testable import VibeVaultApp

@MainActor
final class VaultChangeSignalTests: XCTestCase {
    func test_externalVaultChangeNotification_firesDebouncedSignal() {
        let fired = expectation(description: "signal")
        fired.assertForOverFulfill = false
        var count = 0
        let sub = VaultChangeSignal.publisher.sink { _ in count += 1; fired.fulfill() }
        for _ in 0..<3 {
            DistributedNotificationCenter.default().postNotificationName(
                Notification.Name(VaultChangeNotifier.notificationName), object: nil,
                userInfo: nil, deliverImmediately: true)
        }
        wait(for: [fired], timeout: 3)
        sub.cancel()
        XCTAssertEqual(count, 1, "burst of writes should coalesce into one refresh")
    }

    func test_didBecomeActive_firesSignal() {
        let fired = expectation(description: "active")
        fired.assertForOverFulfill = false
        let sub = VaultChangeSignal.publisher.sink { _ in fired.fulfill() }
        NotificationCenter.default.post(name: NSApplication.didBecomeActiveNotification, object: nil)
        wait(for: [fired], timeout: 3)
        sub.cancel()
    }
}
