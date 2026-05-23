import XCTest
@testable import VaultCore

final class SecretMetadataTests: XCTestCase {
    func test_secret_isExpired_when_past_date() {
        let s = Secret(name: "X", value: "v", expiresAt: Date(timeIntervalSinceNow: -10))
        XCTAssertTrue(s.isExpired)
    }

    func test_secret_isExpired_false_without_expiry() {
        let s = Secret(name: "X", value: "v")
        XCTAssertFalse(s.isExpired)
    }

    func test_rotation_due_when_past_window() {
        let last = Calendar.current.date(byAdding: .day, value: -10, to: Date())
        let s = Secret(name: "X", value: "v", rotateEveryDays: 5, lastRotatedAt: last)
        XCTAssertTrue(s.isRotationDue)
    }

    func test_rotation_not_due_within_window() {
        let s = Secret(name: "X", value: "v", rotateEveryDays: 30, lastRotatedAt: Date())
        XCTAssertFalse(s.isRotationDue)
    }

    func test_keychain_roundtrip_preserves_metadata() throws {
        let store = KeychainStore(service: "dev.vibevault.test.\(UUID().uuidString)")
        let exp = Date(timeIntervalSinceNow: 86_400 * 30)
        let secret = Secret(
            name: "META_TEST", value: "abc", notes: "from test",
            expiresAt: exp, rotateEveryDays: 60
        )
        try store.add(secret)
        let read = try store.read(name: "META_TEST")
        XCTAssertEqual(read.notes, "from test")
        XCTAssertEqual(read.rotateEveryDays, 60)
        XCTAssertNotNil(read.expiresAt)
        if let readExp = read.expiresAt {
            XCTAssertEqual(readExp.timeIntervalSince1970, exp.timeIntervalSince1970, accuracy: 1.0)
        }
        try store.delete(name: "META_TEST")
    }

    func test_legacy_plain_notes_decoded_as_notes() {
        let meta = SecretMetadata.decode("plain text note")
        XCTAssertEqual(meta.notes, "plain text note")
        XCTAssertNil(meta.expiresAt)
    }

    func test_empty_metadata_encodes_to_nil() {
        let meta = SecretMetadata.empty
        XCTAssertNil(meta.encode())
    }
}
