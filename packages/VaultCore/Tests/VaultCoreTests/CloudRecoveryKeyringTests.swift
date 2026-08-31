import XCTest
@testable import VaultCore

final class CloudRecoveryKeyringTests: XCTestCase {
    func test_migrates_legacy_single_key_without_changing_it() throws {
        let prefs = InMemoryPrefs()
        let key = try CloudRecoveryKey.generate()
        prefs.set(Data(key.utf8), forKey: CloudRecoveryKey.preferenceKey)

        let loaded = RecoveryKeyringStore.load(from: prefs)
        XCTAssertEqual(loaded.records.count, 1)
        XCTAssertEqual(loaded.activeCanonicalKey, key)
        XCTAssertEqual(loaded.active?.role, .active)
        XCTAssertEqual(
            prefs.data(forKey: CloudRecoveryKey.preferenceKey),
            Data(key.utf8)
        )
        XCTAssertNotNil(prefs.data(forKey: RecoveryKeyringStore.keyringPreferenceKey))
    }

    func test_rotation_retains_previous_key() throws {
        var keyring = RecoveryKeyring()
        let first = try CloudRecoveryKey.generate()
        let second = try CloudRecoveryKey.generate()
        try keyring.makeActive(first)
        try keyring.makeActive(second)

        XCTAssertEqual(keyring.records.count, 2)
        XCTAssertEqual(keyring.activeCanonicalKey, second)
        XCTAssertEqual(
            keyring.record(identifier: try CloudRecoveryKey.identifier(first))?.role,
            .retained
        )
    }

    func test_keep_for_restores_does_not_replace_active() throws {
        var keyring = RecoveryKeyring()
        let active = try CloudRecoveryKey.generate()
        let entered = try CloudRecoveryKey.generate()
        try keyring.makeActive(active)
        try keyring.addRetained(entered)

        XCTAssertEqual(keyring.activeCanonicalKey, active)
        XCTAssertEqual(
            keyring.record(identifier: try CloudRecoveryKey.identifier(entered))?.role,
            .retained
        )
    }

    func test_cannot_remove_active_key() throws {
        var keyring = RecoveryKeyring()
        let key = try CloudRecoveryKey.generate()
        try keyring.makeActive(key)
        XCTAssertThrowsError(
            try keyring.removeRetained(identifier: try CloudRecoveryKey.identifier(key))
        ) { error in
            XCTAssertEqual(error as? RecoveryKeyringError, .cannotRemoveActive)
        }
        keyring.clearActive()
        XCTAssertEqual(keyring.activeCanonicalKey, nil)
        XCTAssertEqual(keyring.records.first?.role, .retained)
        try keyring.removeRetained(identifier: try CloudRecoveryKey.identifier(key))
        XCTAssertTrue(keyring.records.isEmpty)
    }

    func test_save_keeps_legacy_preference_in_sync_with_active_key() throws {
        let prefs = InMemoryPrefs()
        var keyring = RecoveryKeyring()
        let key = try CloudRecoveryKey.generate()
        try keyring.makeActive(key)
        RecoveryKeyringStore.save(keyring, to: prefs)
        XCTAssertEqual(
            String(data: prefs.data(forKey: CloudRecoveryKey.preferenceKey) ?? Data(), encoding: .utf8),
            key
        )
        keyring.clearActive()
        RecoveryKeyringStore.save(keyring, to: prefs)
        XCTAssertNil(prefs.data(forKey: CloudRecoveryKey.preferenceKey))
    }
}
