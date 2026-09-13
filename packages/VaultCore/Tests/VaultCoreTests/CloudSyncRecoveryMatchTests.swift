import XCTest
@testable import VaultCore

final class CloudSyncRecoveryMatchTests: XCTestCase {
    func test_new_backup_uses_only_the_active_key() throws {
        var keyring = RecoveryKeyring()
        let retained = try CloudRecoveryKey.generate()
        let active = try CloudRecoveryKey.generate()
        try keyring.makeActive(retained)
        try keyring.makeActive(active)
        let encrypted = try CloudSync.encrypt(
            CloudSyncSnapshot(sourceHost: "mac-a", secrets: []),
            passphrase: "correct horse battery staple",
            recoveryKey: keyring.activeCanonicalKey
        )
        let info = try CloudSync.inspect(encrypted)
        XCTAssertEqual(info.recoveryKeyID, try CloudRecoveryKey.identifier(active))
        XCTAssertNotEqual(info.recoveryKeyID, try CloudRecoveryKey.identifier(retained))
    }

    func test_auto_matches_retained_key_without_manual_entry() throws {
        var keyring = RecoveryKeyring()
        let retained = try CloudRecoveryKey.generate()
        try keyring.makeActive(retained)
        let encrypted = try CloudSync.encrypt(
            CloudSyncSnapshot(secrets: [CloudSyncSecret(name: "TOKEN", value: "kept")]),
            passphrase: "correct horse battery staple",
            recoveryKey: retained
        )
        try keyring.makeActive(CloudRecoveryKey.generate())
        let snapshot = try CloudSync.decrypt(encrypted, keyring: keyring)
        XCTAssertEqual(snapshot.secrets.first?.name, "TOKEN")
        XCTAssertEqual(keyring.matchStatus(for: try CloudSync.inspect(encrypted)), .matchedRetained)
    }

    func test_legacy_bundle_without_identity_still_decrypts() throws {
        let key = try CloudRecoveryKey.generate()
        let snapshot = CloudSyncSnapshot(secrets: [CloudSyncSecret(name: "OLD", value: "ok")])
        let encrypted = try CloudSync.encrypt(
            snapshot,
            passphrase: "correct horse battery staple",
            recoveryKey: key
        )
        let legacy = try stripRecoveryIdentity(encrypted)
        let info = try CloudSync.inspect(legacy)
        XCTAssertTrue(info.isLegacyRecovery)
        XCTAssertEqual(try CloudSync.decrypt(legacy, recoveryKey: key), snapshot)

        var keyring = RecoveryKeyring()
        try keyring.makeActive(key)
        XCTAssertEqual(try CloudSync.decrypt(legacy, keyring: keyring), snapshot)
        XCTAssertEqual(keyring.matchStatus(for: info), .legacyUnknown)
    }

    func test_legacy_bundle_fallback_tries_retained_keys() throws {
        var keyring = RecoveryKeyring()
        let matching = try CloudRecoveryKey.generate()
        try keyring.makeActive(matching)
        try keyring.makeActive(CloudRecoveryKey.generate())
        let encrypted = try CloudSync.encrypt(
            CloudSyncSnapshot(secrets: [CloudSyncSecret(name: "LEGACY", value: "yes")]),
            passphrase: "correct horse battery staple",
            recoveryKey: matching
        )
        let legacy = try stripRecoveryIdentity(encrypted)
        let snapshot = try CloudSync.decrypt(legacy, keyring: keyring)
        XCTAssertEqual(snapshot.secrets.first?.name, "LEGACY")
    }

    func test_missing_installed_key_reports_fingerprint() throws {
        let key = try CloudRecoveryKey.generate()
        let encrypted = try CloudSync.encrypt(
            CloudSyncSnapshot(secrets: []),
            passphrase: "correct horse battery staple",
            recoveryKey: key
        )
        XCTAssertThrowsError(try CloudSync.decrypt(encrypted, keyring: RecoveryKeyring())) { error in
            XCTAssertEqual(
                error as? CloudSyncError,
                .recoveryKeyNotInstalled(
                    fingerprint: (try? CloudRecoveryKey.fingerprint(forKey: key)) ?? ""
                )
            )
        }
    }

    func test_preview_decrypt_does_not_mutate_keyring_or_bundle() throws {
        let prefs = InMemoryPrefs()
        var keyring = RecoveryKeyring()
        let key = try CloudRecoveryKey.generate()
        try keyring.makeActive(key)
        RecoveryKeyringStore.save(keyring, to: prefs)
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = directory.appendingPathComponent("vault.vvsync")
        let encrypted = try CloudSync.encrypt(
            CloudSyncSnapshot(secrets: [CloudSyncSecret(name: "A", value: "1")]),
            passphrase: "correct horse battery staple",
            recoveryKey: key
        )
        try encrypted.write(to: url)
        let beforePrefs = prefs.data(forKey: RecoveryKeyringStore.keyringPreferenceKey)
        let beforeLegacy = prefs.data(forKey: CloudRecoveryKey.preferenceKey)
        let beforeBundle = try Data(contentsOf: url)

        _ = try CloudSync.inspect(try Data(contentsOf: url))
        _ = try CloudSync.decrypt(try Data(contentsOf: url), keyring: RecoveryKeyringStore.load(from: prefs))

        XCTAssertEqual(prefs.data(forKey: RecoveryKeyringStore.keyringPreferenceKey), beforePrefs)
        XCTAssertEqual(prefs.data(forKey: CloudRecoveryKey.preferenceKey), beforeLegacy)
        XCTAssertEqual(try Data(contentsOf: url), beforeBundle)
    }

    func test_safe_removal_counts_dependent_bundles() throws {
        let matching = try CloudRecoveryKey.generate()
        let other = try CloudRecoveryKey.generate()
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let matchURL = directory.appendingPathComponent("match.vvsync")
        let otherURL = directory.appendingPathComponent("other.vvsync")
        let legacyURL = directory.appendingPathComponent("legacy.vvsync")
        try CloudSync.encrypt(
            CloudSyncSnapshot(secrets: []),
            passphrase: "correct horse battery staple",
            recoveryKey: matching
        ).write(to: matchURL)
        try CloudSync.encrypt(
            CloudSyncSnapshot(secrets: []),
            passphrase: "correct horse battery staple",
            recoveryKey: other
        ).write(to: otherURL)
        try stripRecoveryIdentity(
            try CloudSync.encrypt(
                CloudSyncSnapshot(secrets: []),
                passphrase: "correct horse battery staple",
                recoveryKey: matching
            )
        ).write(to: legacyURL)

        let dependents = RecoveryKeyBundleScanner.scan(
            identifier: try CloudRecoveryKey.identifier(matching),
            urls: [matchURL, otherURL, legacyURL]
        )
        XCTAssertEqual(dependents.matchingCount, 1)
        XCTAssertEqual(dependents.legacyUnattributedCount, 1)
        XCTAssertEqual(dependents.scannedCount, 3)
    }
}

private func stripRecoveryIdentity(_ data: Data) throws -> Data {
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    let envelope = try decoder.decode(CloudSyncEnvelope.self, from: data)
    let stripped = CloudSyncEnvelope(
        version: envelope.version,
        createdAt: envelope.createdAt,
        sourceHost: envelope.sourceHost,
        kdf: envelope.kdf,
        kdfIterations: envelope.kdfIterations,
        cipher: envelope.cipher,
        salt: envelope.salt,
        nonce: envelope.nonce,
        tag: envelope.tag,
        ciphertext: envelope.ciphertext,
        passphraseNonce: envelope.passphraseNonce,
        passphraseTag: envelope.passphraseTag,
        passphraseWrappedKey: envelope.passphraseWrappedKey,
        recoveryKdf: envelope.recoveryKdf,
        recoverySalt: envelope.recoverySalt,
        recoveryNonce: envelope.recoveryNonce,
        recoveryTag: envelope.recoveryTag,
        recoveryWrappedKey: envelope.recoveryWrappedKey
    )
    let encoder = JSONEncoder()
    encoder.dateEncodingStrategy = .iso8601
    return try encoder.encode(stripped)
}
