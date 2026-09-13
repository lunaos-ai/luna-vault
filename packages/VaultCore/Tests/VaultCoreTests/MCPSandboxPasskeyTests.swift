import XCTest
@testable import VaultCore

final class MCPSandboxPasskeyTests: XCTestCase {
    func test_enroll_and_verify_matching_passkey() throws {
        let prefs = InMemoryPrefs()
        let store = MCPSandboxPasskeyStore(prefs: prefs)
        XCTAssertFalse(store.isEnrolled)
        try store.enroll("correct horse battery")
        XCTAssertTrue(store.isEnrolled)
        XCTAssertEqual(try store.verify("correct horse battery"), true)
        XCTAssertEqual(try store.verify("wrong passkey!!"), false)
    }

    func test_enroll_rejects_short_passkey() {
        let store = MCPSandboxPasskeyStore(prefs: InMemoryPrefs())
        XCTAssertThrowsError(try store.enroll("short")) { error in
            XCTAssertEqual(error as? MCPSandboxError, .passkeyTooShort)
        }
    }

    func test_verify_without_enroll_throws() {
        let store = MCPSandboxPasskeyStore(prefs: InMemoryPrefs())
        XCTAssertThrowsError(try store.verify("long-enough-key")) { error in
            XCTAssertEqual(error as? MCPSandboxError, .passkeyNotEnrolled)
        }
    }

    func test_clear_removes_enrollment() throws {
        let prefs = InMemoryPrefs()
        let store = MCPSandboxPasskeyStore(prefs: prefs)
        try store.enroll("correct horse battery")
        store.clear()
        XCTAssertFalse(store.isEnrolled)
    }
}

final class MCPSandboxTokenTests: XCTestCase {
    func test_minted_token_validates_until_expiry() throws {
        let prefs = InMemoryPrefs()
        try MCPSandboxPasskeyStore(prefs: prefs).enroll("correct horse battery")
        let token = try MCPSandboxTokenMint.mint(minutes: 30, prefs: prefs)
        XCTAssertTrue(MCPSandboxTokenMint.validate(token.value, prefs: prefs))
        XCTAssertTrue(token.expiresAt.timeIntervalSinceNow > 60)
    }

    func test_expired_token_is_rejected() throws {
        let prefs = InMemoryPrefs()
        try MCPSandboxPasskeyStore(prefs: prefs).enroll("correct horse battery")
        let token = try MCPSandboxTokenMint.mint(minutes: 30, prefs: prefs)
        let later = Date().addingTimeInterval(31 * 60)
        XCTAssertFalse(MCPSandboxTokenMint.validate(token.value, prefs: prefs, now: later))
    }

    func test_tampered_token_is_rejected() throws {
        let prefs = InMemoryPrefs()
        try MCPSandboxPasskeyStore(prefs: prefs).enroll("correct horse battery")
        let token = try MCPSandboxTokenMint.mint(minutes: 30, prefs: prefs)
        XCTAssertFalse(MCPSandboxTokenMint.validate(token.value + "x", prefs: prefs))
        XCTAssertFalse(MCPSandboxTokenMint.validate("not-a-token", prefs: prefs))
    }

    func test_reenroll_invalidates_old_tokens() throws {
        let prefs = InMemoryPrefs()
        let store = MCPSandboxPasskeyStore(prefs: prefs)
        try store.enroll("correct horse battery")
        let token = try MCPSandboxTokenMint.mint(minutes: 30, prefs: prefs)
        try store.enroll("correct horse staple")
        XCTAssertFalse(MCPSandboxTokenMint.validate(token.value, prefs: prefs))
    }
}
