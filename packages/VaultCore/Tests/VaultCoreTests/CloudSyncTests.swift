import XCTest
@testable import VaultCore

private extension JSONDecoder {
    static var iso8601: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}

private extension JSONEncoder {
    static var iso8601: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }
}

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

    func test_envelope_declares_slow_kdf_with_stored_iterations() throws {
        let snapshot = CloudSyncSnapshot(secrets: [])
        let encrypted = try CloudSync.encrypt(snapshot, passphrase: "correct horse battery staple")

        let envelope = try JSONDecoder.iso8601.decode(CloudSyncEnvelope.self, from: encrypted)
        XCTAssertEqual(envelope.kdf, "pbkdf2-sha256+hkdf-sha256")
        XCTAssertGreaterThanOrEqual(envelope.kdfIterations, 600_000)
    }

    func test_decrypt_rejects_downgraded_iteration_count() throws {
        let snapshot = CloudSyncSnapshot(secrets: [])
        let encrypted = try CloudSync.encrypt(snapshot, passphrase: "correct horse battery staple")
        let envelope = try JSONDecoder.iso8601.decode(CloudSyncEnvelope.self, from: encrypted)

        let downgraded = CloudSyncEnvelope(
            version: envelope.version,
            createdAt: envelope.createdAt,
            sourceHost: envelope.sourceHost,
            kdf: envelope.kdf,
            kdfIterations: 1,
            cipher: envelope.cipher,
            salt: envelope.salt,
            nonce: envelope.nonce,
            tag: envelope.tag,
            ciphertext: envelope.ciphertext
        )
        let data = try JSONEncoder.iso8601.encode(downgraded)

        XCTAssertThrowsError(try CloudSync.decrypt(data, passphrase: "correct horse battery staple")) { error in
            XCTAssertEqual(error as? CloudSyncError, .corruptEnvelope)
        }
    }

    func test_decrypt_rejects_legacy_fast_kdf_envelope() throws {
        let snapshot = CloudSyncSnapshot(secrets: [])
        let encrypted = try CloudSync.encrypt(snapshot, passphrase: "correct horse battery staple")
        let envelope = try JSONDecoder.iso8601.decode(CloudSyncEnvelope.self, from: encrypted)

        let legacy = CloudSyncEnvelope(
            version: envelope.version,
            createdAt: envelope.createdAt,
            sourceHost: envelope.sourceHost,
            kdf: "hkdf-sha256",
            kdfIterations: envelope.kdfIterations,
            cipher: envelope.cipher,
            salt: envelope.salt,
            nonce: envelope.nonce,
            tag: envelope.tag,
            ciphertext: envelope.ciphertext
        )
        let data = try JSONEncoder.iso8601.encode(legacy)

        XCTAssertThrowsError(try CloudSync.decrypt(data, passphrase: "correct horse battery staple")) { error in
            XCTAssertEqual(error as? CloudSyncError, .corruptEnvelope)
        }
    }

    func test_default_icloud_path_is_vibevault_sync_bundle() {
        let path = CloudSync.defaultICloudURL().path
        XCTAssertTrue(path.contains("Mobile Documents/com~apple~CloudDocs/Documents"))
        XCTAssertTrue(path.hasSuffix("VibeVault/Sync/vault.vvsync"))
    }
}
