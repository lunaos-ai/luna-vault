import XCTest
@testable import VibeVaultApp
@testable import VaultCore

@MainActor
final class SchedulerSettingsTests: XCTestCase {
    // MARK: ExpiryScheduler

    func test_runOnce_withNoExpiringSecrets_recordsZeroAlerts() async {
        let secrets = [Secret(name: "A", value: "1"), Secret(name: "B", value: "2")]
        let sched = ExpiryScheduler(secretsProvider: { secrets })
        await sched.runOnce(warnWithinDays: 14)
        XCTAssertEqual(sched.lastAlertCount, 0)
        XCTAssertNotNil(sched.lastRunAt)
    }

    func test_stop_isIdempotent() {
        let sched = ExpiryScheduler(secretsProvider: { [] })
        sched.stop()
        sched.stop()
        XCTAssertNil(sched.lastRunAt)
    }

    func test_resetDedupe_doesNotThrow() {
        let sched = ExpiryScheduler(secretsProvider: { [] })
        sched.resetDedupe()
    }

    // MARK: AppSettings

    func test_defaults() {
        let s = AppSettings()
        XCTAssertEqual(s.sessionMinutes, 5)
        XCTAssertTrue(s.notificationsEnabled)
        XCTAssertEqual(s.warnWithinDays, 14)
    }

    func test_codableRoundtrip() throws {
        var s = AppSettings()
        s.sessionMinutes = 12
        s.warnWithinDays = 30
        s.notificationsEnabled = false
        let data = try JSONEncoder().encode(s)
        let back = try JSONDecoder().decode(AppSettings.self, from: data)
        XCTAssertEqual(s, back)
    }

    func test_migrateLegacy_readsAndClearsUserDefaults() {
        let d = UserDefaults.standard
        d.set(20.0, forKey: "vibe-vault.biometric.session-minutes")
        d.set(false, forKey: "vibe-vault.notifications.enabled")
        d.set(7, forKey: "vibe-vault.notifications.warn-within-days")

        let prefs = MemPrefs()
        let migrated = AppSettings.migrateLegacy(into: prefs, settingsKey: "k")
        XCTAssertEqual(migrated.sessionMinutes, 20)
        XCTAssertFalse(migrated.notificationsEnabled)
        XCTAssertEqual(migrated.warnWithinDays, 7)
        XCTAssertNotNil(prefs.codable(AppSettings.self, forKey: "k"))
        XCTAssertNil(d.object(forKey: "vibe-vault.biometric.session-minutes"))
    }
}
