import CryptoKit
import XCTest
@testable import VaultCore

final class SharedUnlockSessionTests: XCTestCase {
    private var url: URL!
    private var key: SymmetricKey!

    override func setUp() {
        url = FileManager.default.temporaryDirectory
            .appendingPathComponent("vv-unlock-\(UUID().uuidString).json")
        key = SymmetricKey(size: .bits256)
    }

    override func tearDown() {
        SharedUnlockSession.lock(url: url)
    }

    func test_unlock_is_shared_and_private() throws {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let status = try SharedUnlockSession.unlock(
            for: 900, at: now, url: url, authenticationKey: key
        )

        XCTAssertEqual(status.expiresAt, now.addingTimeInterval(900))
        XCTAssertTrue(SharedUnlockSession.isUnlocked(
            at: now.addingTimeInterval(60), url: url, authenticationKey: key
        ))
        let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
        XCTAssertEqual((attributes[.posixPermissions] as? NSNumber)?.intValue, 0o600)
    }

    func test_expired_session_is_removed() throws {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        _ = try SharedUnlockSession.unlock(
            for: 300, at: now, url: url, authenticationKey: key
        )

        XCTAssertNil(SharedUnlockSession.status(
            at: now.addingTimeInterval(301), url: url, authenticationKey: key
        ))
        XCTAssertFalse(FileManager.default.fileExists(atPath: url.path))
    }

    func test_duration_is_bounded() throws {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let short = try SharedUnlockSession.unlock(
            for: 1, at: now, url: url, authenticationKey: key
        )
        XCTAssertEqual(short.expiresAt, now.addingTimeInterval(SharedUnlockSession.minimumDuration))

        let long = try SharedUnlockSession.unlock(
            for: 99_999, at: now, url: url, authenticationKey: key
        )
        XCTAssertEqual(long.expiresAt, now.addingTimeInterval(SharedUnlockSession.maximumDuration))
    }

    func test_insecure_permissions_are_rejected() throws {
        _ = try SharedUnlockSession.unlock(for: 900, url: url, authenticationKey: key)
        try FileManager.default.setAttributes([.posixPermissions: 0o644], ofItemAtPath: url.path)

        XCTAssertNil(SharedUnlockSession.status(url: url, authenticationKey: key))
    }

    func test_lock_revokes_session_immediately() throws {
        _ = try SharedUnlockSession.unlock(for: 900, url: url, authenticationKey: key)
        SharedUnlockSession.lock(url: url)

        XCTAssertFalse(SharedUnlockSession.isUnlocked(url: url, authenticationKey: key))
    }

    func test_forged_authentication_code_is_rejected() throws {
        _ = try SharedUnlockSession.unlock(for: 900, url: url, authenticationKey: key)
        let forgedKey = SymmetricKey(size: .bits256)

        XCTAssertNil(SharedUnlockSession.status(url: url, authenticationKey: forgedKey))
        XCTAssertFalse(FileManager.default.fileExists(atPath: url.path))
    }
}
