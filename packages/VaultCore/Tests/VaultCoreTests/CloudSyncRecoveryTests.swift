import Foundation
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

    func test_recovery_key_rejects_wrong_key() throws {
        let encrypted = try CloudSync.encrypt(
            CloudSyncSnapshot(secrets: []),
            passphrase: "correct horse battery staple",
            recoveryKey: CloudRecoveryKey.generate()
        )

        XCTAssertThrowsError(
            try CloudSync.decrypt(encrypted, recoveryKey: CloudRecoveryKey.generate())
        ) { error in
            XCTAssertEqual(error as? CloudSyncError, .authenticationFailed)
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
}
