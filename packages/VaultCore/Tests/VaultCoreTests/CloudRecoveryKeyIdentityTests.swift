import XCTest
@testable import VaultCore

final class CloudRecoveryKeyIdentityTests: XCTestCase {
    func test_fingerprint_is_deterministic_after_canonicalization() throws {
        let key = try CloudRecoveryKey.generate()
        let identifier = try CloudRecoveryKey.identifier(key)
        XCTAssertEqual(identifier.count, 64)
        XCTAssertEqual(try CloudRecoveryKey.identifier(key.lowercased()), identifier)
        XCTAssertEqual(
            try CloudRecoveryKey.fingerprint(forKey: key),
            CloudRecoveryKey.fingerprint(identifier: identifier)
        )
        let fingerprint = CloudRecoveryKey.fingerprint(identifier: identifier)
        XCTAssertTrue(fingerprint.contains("\u{2026}"))
        XCTAssertEqual(fingerprint.split(separator: "-").count, 4)
        XCTAssertNotEqual(fingerprint, key)
        XCTAssertFalse(fingerprint.contains("VV-RK1"))
    }

    func test_identifier_never_equals_canonical_key() throws {
        let key = try CloudRecoveryKey.generate()
        let identifier = try CloudRecoveryKey.identifier(key)
        XCTAssertFalse(key.contains(identifier))
        XCTAssertFalse(identifier.contains("VV"))
    }

    func test_recovery_kit_includes_fingerprint_and_created_date() throws {
        let key = try CloudRecoveryKey.generate()
        let created = Date(timeIntervalSince1970: 1_800_000_000)
        let kit = try RecoveryKitDocument.contents(canonicalKey: key, createdAt: created)
        XCTAssertTrue(kit.contains(try CloudRecoveryKey.fingerprint(forKey: key)))
        XCTAssertTrue(kit.contains(ISO8601DateFormatter().string(from: created)))
        XCTAssertTrue(kit.contains(key))
        XCTAssertTrue(kit.contains("Fingerprint:"))
        XCTAssertTrue(kit.contains("Created:"))
    }
}
