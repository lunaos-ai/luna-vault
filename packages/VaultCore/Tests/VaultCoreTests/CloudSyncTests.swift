import CommonCrypto
import CryptoKit
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
                    mcpAllowed: true,
                    totpAuthURL: "otpauth://totp/Gemini:dev@example.com?secret=JBSWY3DPEHPK3PXP&issuer=Gemini"
                )
            ]
        )

        let encrypted = try CloudSync.encrypt(snapshot, passphrase: "correct horse battery staple")
        let decrypted = try CloudSync.decrypt(encrypted, passphrase: "correct horse battery staple")

        XCTAssertEqual(decrypted, snapshot)
    }

    func test_encrypt_decrypt_roundTripsStandaloneAuthenticatorsInVersionThree() throws {
        let timestamp = Date(timeIntervalSince1970: 1_800_000_000)
        let account = AuthenticatorAccount(
            issuer: "Example", accountName: "alice@example.com",
            secret: Data("totp-seed".utf8), createdAt: timestamp, updatedAt: timestamp
        )
        let revision = AuthenticatorRevision(
            account: account, capturedAt: timestamp, action: .created, sourceHost: "mac-a"
        )
        let snapshot = CloudSyncSnapshot(
            secrets: [], authenticatorAccounts: [account],
            authenticatorRevisions: [revision]
        )

        let encrypted = try CloudSync.encrypt(
            snapshot, passphrase: "correct horse battery staple"
        )
        let decrypted = try CloudSync.decrypt(
            encrypted, passphrase: "correct horse battery staple"
        )

        XCTAssertEqual(decrypted.version, 3)
        XCTAssertEqual(decrypted.authenticatorAccounts, [account])
        XCTAssertEqual(decrypted.authenticatorRevisions, [revision])
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

    func test_decrypt_remains_compatible_with_v1_bundle() throws {
        let timestamp = Date(timeIntervalSince1970: 1_800_000_000)
        let snapshot = CloudSyncSnapshot(
            version: 1,
            exportedAt: timestamp,
            sourceHost: "legacy-mac",
            secrets: [CloudSyncSecret(name: "OLD", value: "still-readable", updatedAt: timestamp)]
        )
        let data = try makeLegacyV1Bundle(
            snapshot: snapshot,
            passphrase: "correct horse battery staple"
        )

        XCTAssertEqual(
            try CloudSync.decrypt(data, passphrase: "correct horse battery staple"),
            snapshot
        )
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

}

private func makeLegacyV1Bundle(snapshot: CloudSyncSnapshot, passphrase: String) throws -> Data {
    let salt = Data(repeating: 7, count: 32)
    var stretched = Data(count: 32)
    let status = stretched.withUnsafeMutableBytes { stretchedBytes in
        salt.withUnsafeBytes { saltBytes in
            CCKeyDerivationPBKDF(
                CCPBKDFAlgorithm(kCCPBKDF2),
                passphrase,
                passphrase.utf8.count,
                saltBytes.bindMemory(to: UInt8.self).baseAddress,
                salt.count,
                CCPseudoRandomAlgorithm(kCCPRFHmacAlgSHA256),
                600_000,
                stretchedBytes.bindMemory(to: UInt8.self).baseAddress,
                32
            )
        }
    }
    XCTAssertEqual(status, Int32(kCCSuccess))
    let key = HKDF<SHA256>.deriveKey(
        inputKeyMaterial: SymmetricKey(data: stretched),
        salt: salt,
        info: Data("vibevault-cloud-sync-v1".utf8),
        outputByteCount: 32
    )
    let plain = try JSONEncoder.iso8601.encode(snapshot)
    let sealed = try AES.GCM.seal(plain, using: key)
    let envelope = CloudSyncEnvelope(
        version: 1,
        createdAt: snapshot.exportedAt,
        sourceHost: snapshot.sourceHost,
        kdf: "pbkdf2-sha256+hkdf-sha256",
        kdfIterations: 600_000,
        cipher: "aes-256-gcm",
        salt: salt.base64EncodedString(),
        nonce: sealed.nonce.withUnsafeBytes { Data($0).base64EncodedString() },
        tag: sealed.tag.base64EncodedString(),
        ciphertext: sealed.ciphertext.base64EncodedString()
    )
    return try JSONEncoder.iso8601.encode(envelope)
}
