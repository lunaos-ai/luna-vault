import XCTest
@testable import VaultCore

final class CloudSyncTests: XCTestCase {
    func test_encrypt_decrypt_round_trips_snapshot() throws {
        let exportedAt = Date(timeIntervalSince1970: 1_800_000_000)
        let expiresAt = Date(timeIntervalSince1970: 1_900_000_000)
        let snapshot = CloudSyncSnapshot(
            exportedAt: exportedAt,
            sourceHost: "mac-a",
            secrets: [
                CloudSyncSecret(
                    name: "GEMINI_API_KEY",
                    value: "AIza-test-value",
                    updatedAt: exportedAt,
                    notes: "imported from browser",
                    expiresAt: expiresAt,
                    rotateEveryDays: 30,
                    lastRotatedAt: exportedAt,
                    mcpAllowed: true
                )
            ]
        )

        let encrypted = try CloudSync.encrypt(snapshot, passphrase: "correct horse battery staple")
        let decrypted = try CloudSync.decrypt(encrypted, passphrase: "correct horse battery staple")

        XCTAssertEqual(decrypted, snapshot)
    }

    func test_decrypt_rejects_wrong_passphrase() throws {
        let snapshot = CloudSyncSnapshot(
            sourceHost: "mac-a",
            secrets: [CloudSyncSecret(name: "TOKEN", value: "secret-value")]
        )
        let encrypted = try CloudSync.encrypt(snapshot, passphrase: "correct horse battery staple")

        XCTAssertThrowsError(try CloudSync.decrypt(encrypted, passphrase: "wrong horse battery staple")) { error in
            XCTAssertEqual(error as? CloudSyncError, .authenticationFailed)
        }
    }

    func test_encrypt_rejects_weak_passphrase() {
        let snapshot = CloudSyncSnapshot(secrets: [])

        XCTAssertThrowsError(try CloudSync.encrypt(snapshot, passphrase: "short")) { error in
            XCTAssertEqual(error as? CloudSyncError, .weakPassphrase)
        }
    }

    func test_default_icloud_path_is_vibevault_sync_bundle() {
        let path = CloudSync.defaultICloudURL().path
        XCTAssertTrue(path.contains("Mobile Documents/com~apple~CloudDocs/Documents"))
        XCTAssertTrue(path.hasSuffix("VibeVault/Sync/vault.vvsync"))
    }
}
