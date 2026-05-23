import XCTest
@testable import VaultCore

final class ExpiryWatcherTests: XCTestCase {
    private let watcher = ExpiryWatcher()

    func test_expired_secret_produces_expired_alert() {
        let now = Date()
        let s = Secret(name: "EXP", value: "v", expiresAt: now.addingTimeInterval(-3600))
        let alerts = watcher.scan(secrets: [s], warnWithinDays: 14, now: now)
        XCTAssertEqual(alerts.first?.kind, .expired)
        XCTAssertEqual(alerts.first?.secretName, "EXP")
    }

    func test_secret_expiring_within_window_produces_expiring_alert() {
        let now = Date()
        let due = Calendar.current.date(byAdding: .day, value: 3, to: now)!
        let s = Secret(name: "SOON", value: "v", expiresAt: due)
        let alerts = watcher.scan(secrets: [s], warnWithinDays: 14, now: now)
        XCTAssertEqual(alerts.first?.kind, .expiringSoon)
    }

    func test_secret_outside_window_produces_no_alert() {
        let now = Date()
        let due = Calendar.current.date(byAdding: .day, value: 60, to: now)!
        let s = Secret(name: "FAR", value: "v", expiresAt: due)
        let alerts = watcher.scan(secrets: [s], warnWithinDays: 14, now: now)
        XCTAssertTrue(alerts.isEmpty)
    }

    func test_rotation_due_secret_produces_rotation_alert() {
        let now = Date()
        let lastRotated = Calendar.current.date(byAdding: .day, value: -100, to: now)!
        let s = Secret(name: "ROT", value: "v", rotateEveryDays: 30, lastRotatedAt: lastRotated)
        let alerts = watcher.scan(secrets: [s], warnWithinDays: 14, now: now)
        XCTAssertTrue(alerts.contains { $0.kind == .rotationDue })
    }

    func test_alert_body_includes_secret_name() {
        let alert = ExpiryAlert(secretName: "MY_KEY", kind: .expired, dueDate: Date())
        XCTAssertTrue(alert.body.contains("MY_KEY"))
        XCTAssertEqual(alert.title, "Secret expired")
    }

    func test_alert_id_is_stable_per_kind() {
        let a = ExpiryAlert(secretName: "X", kind: .expired, dueDate: Date())
        let b = ExpiryAlert(secretName: "X", kind: .expired, dueDate: Date().addingTimeInterval(100))
        XCTAssertEqual(a.id, b.id)
    }

    func test_dedupe_filters_already_delivered() {
        let defaults = UserDefaults(suiteName: "test-\(UUID().uuidString)")!
        let dedupe = AlertDedupe(userDefaults: defaults, key: "test-key")
        let alert = ExpiryAlert(secretName: "X", kind: .expired, dueDate: nil)
        XCTAssertEqual(dedupe.filterNew([alert]).count, 1)
        dedupe.markDelivered([alert])
        XCTAssertEqual(dedupe.filterNew([alert]).count, 0)
        dedupe.reset()
        XCTAssertEqual(dedupe.filterNew([alert]).count, 1)
    }
}
