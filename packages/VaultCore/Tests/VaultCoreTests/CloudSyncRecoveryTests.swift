import XCTest
@testable import VaultCore

final class CloudSyncRecoveryTests: XCTestCase {
    func test_recovery_key_decrypts_bundle_independently() throws {
        let recoveryKey = try CloudRecoveryKey.generate()
        let capturedAt = Date(timeIntervalSince1970: 1_800_000_000)
        let snapshot = CloudSyncSnapshot(
            exportedAt: capturedAt,
            secrets: [CloudSyncSecret(name: "TOKEN", value: "recover-me", updatedAt: capturedAt)],
            revisions: [
                SecretRevision(
                    secret: Secret(name: "TOKEN", value: "older-value", updatedAt: capturedAt),
                    capturedAt: capturedAt,
                    action: .rotated,
                    sourceHost: "mac-a"
                )
            ]
        )
        let encrypted = try CloudSync.encrypt(
            snapshot,
            passphrase: "correct horse battery staple",
            recoveryKey: recoveryKey
        )

        XCTAssertEqual(try CloudSync.decrypt(encrypted, recoveryKey: recoveryKey), snapshot)
        XCTAssertEqual(
            try CloudSync.decrypt(encrypted, passphrase: "correct horse battery staple"),
            snapshot
        )
    }

    func test_new_bundle_stores_non_secret_recovery_key_identity() throws {
        let recoveryKey = try CloudRecoveryKey.generate()
        let encrypted = try CloudSync.encrypt(
            CloudSyncSnapshot(secrets: []),
            passphrase: "correct horse battery staple",
            recoveryKey: recoveryKey
        )
        let info = try CloudSync.inspect(encrypted)
        XCTAssertTrue(info.hasRecoveryProtection)
        XCTAssertEqual(info.recoveryKeyID, try CloudRecoveryKey.identifier(recoveryKey))
        XCTAssertNotNil(info.recoveryProtectedAt)
        XCTAssertEqual(
            info.recoveryFingerprint,
            try CloudRecoveryKey.fingerprint(forKey: recoveryKey)
        )
        let json = String(data: encrypted, encoding: .utf8) ?? ""
        XCTAssertFalse(json.contains(recoveryKey))
        XCTAssertFalse(json.contains("VV-RK1"))
    }

    func test_recovery_key_rejects_wrong_key_as_mismatch() throws {
        let matching = try CloudRecoveryKey.generate()
        let encrypted = try CloudSync.encrypt(
            CloudSyncSnapshot(secrets: []),
            passphrase: "correct horse battery staple",
            recoveryKey: matching
        )
        let other = try CloudRecoveryKey.generate()

        XCTAssertThrowsError(try CloudSync.decrypt(encrypted, recoveryKey: other)) { error in
            XCTAssertEqual(
                error as? CloudSyncError,
                .recoveryKeyMismatch(
                    expectedFingerprint: try? CloudRecoveryKey.fingerprint(forKey: matching),
                    enteredFingerprint: (try? CloudRecoveryKey.fingerprint(forKey: other)) ?? ""
                )
            )
        }
    }

    func test_malformed_key_fails_before_decryption() {
        XCTAssertThrowsError(
            try CloudSync.decrypt(Data("not-json".utf8), recoveryKey: "not-a-recovery-key")
        ) { error in
            XCTAssertEqual(error as? CloudSyncError, .invalidRecoveryKey)
        }
    }

    func test_bundle_without_recovery_wrapper_reports_unavailable() throws {
        let encrypted = try CloudSync.encrypt(
            CloudSyncSnapshot(secrets: []),
            passphrase: "correct horse battery staple"
        )

        XCTAssertThrowsError(
            try CloudSync.decrypt(encrypted, recoveryKey: CloudRecoveryKey.generate())
        ) { error in
            XCTAssertEqual(error as? CloudSyncError, .recoveryUnavailable)
        }
    }

    func test_recovery_key_has_stable_printable_format() throws {
        let generated = try CloudRecoveryKey.generate()
        XCTAssertTrue(generated.hasPrefix("VV-RK1-"))
        XCTAssertEqual(try CloudRecoveryKey.canonicalize(generated.lowercased()), generated)
        XCTAssertThrowsError(try CloudRecoveryKey.canonicalize("not-a-recovery-key"))
    }

    func test_errors_and_envelopes_do_not_leak_raw_keys() throws {
        let matching = try CloudRecoveryKey.generate()
        let other = try CloudRecoveryKey.generate()
        let encrypted = try CloudSync.encrypt(
            CloudSyncSnapshot(secrets: []),
            passphrase: "correct horse battery staple",
            recoveryKey: matching
        )
        let json = String(data: encrypted, encoding: .utf8) ?? ""
        XCTAssertFalse(json.contains(matching))
        XCTAssertFalse(json.contains(other))
        do {
            _ = try CloudSync.decrypt(encrypted, recoveryKey: other)
            XCTFail("expected mismatch")
        } catch let error as CloudSyncError {
            let text = error.description
            XCTAssertFalse(text.contains(matching))
            XCTAssertFalse(text.contains(other))
            XCTAssertFalse(text.contains("VV-RK1"))
        }
    }
}
