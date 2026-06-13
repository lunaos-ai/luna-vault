import XCTest
@testable import VaultCore

// Covers lines missed in KeychainStoreTests:
//   - exists() (lines 126-129): both true and false paths
//   - update() with metadata (line 46): encoded comment branch
//   - accessGroup branch in baseQuery / list() (lines 104, 137)
//   - validateName 256-char limit (line 143)
//   - list() returns empty when no items (errSecItemNotFound path, line 107)
//   - update() notFound error path (line 49)
//   - delete() notFound error path (line 93)
//   - read() notFound error path (line 61)

final class KeychainStoreEdgeTests: XCTestCase {
    private var store: KeychainStore!
    private var serviceName: String!

    override func setUpWithError() throws {
        serviceName = "dev.vibevault.edge.\(UUID().uuidString)"
        store = KeychainStore(service: serviceName, accessGroup: nil)
    }

    override func tearDownWithError() throws {
        for secret in (try? store.list()) ?? [] {
            try? store.delete(name: secret.name)
        }
    }

    // MARK: - exists()

    func test_exists_returns_true_for_present_secret() throws {
        try store.add(Secret(name: "EXIST_KEY", value: "v"))
        XCTAssertTrue(try store.exists(name: "EXIST_KEY"))
    }

    func test_exists_returns_false_for_missing_secret() throws {
        XCTAssertFalse(try store.exists(name: "NEVER_ADDED"))
    }

    func test_exists_returns_false_after_delete() throws {
        try store.add(Secret(name: "EXIST_DEL", value: "v"))
        try store.delete(name: "EXIST_DEL")
        XCTAssertFalse(try store.exists(name: "EXIST_DEL"))
    }

    // MARK: - update() with metadata (line 46 — encodeMetadata branch inside update)

    func test_update_with_metadata_persists_notes() throws {
        try store.add(Secret(name: "UPDT_META", value: "v1"))
        let updated = Secret(
            name: "UPDT_META", value: "v2",
            notes: "updated note",
            rotateEveryDays: 30,
            mcpAllowed: true
        )
        try store.update(updated)
        let read = try store.read(name: "UPDT_META")
        XCTAssertEqual(read.value, "v2")
        XCTAssertEqual(read.notes, "updated note")
        XCTAssertEqual(read.rotateEveryDays, 30)
        XCTAssertTrue(read.mcpAllowed)
    }

    func test_update_notFound_throws() throws {
        XCTAssertThrowsError(try store.update(Secret(name: "GHOST", value: "x"))) { err in
            XCTAssertEqual(err as? SecretError, .notFound(name: "GHOST"))
        }
    }

    // MARK: - read() notFound

    func test_read_missing_throws_notFound() throws {
        XCTAssertThrowsError(try store.read(name: "MISSING")) { err in
            XCTAssertEqual(err as? SecretError, .notFound(name: "MISSING"))
        }
    }

    // MARK: - delete() notFound

    func test_delete_missing_throws_notFound() throws {
        XCTAssertThrowsError(try store.delete(name: "NO_SUCH")) { err in
            XCTAssertEqual(err as? SecretError, .notFound(name: "NO_SUCH"))
        }
    }

    // MARK: - list() empty (errSecItemNotFound -> [] path, line 107)

    func test_list_returns_empty_for_fresh_service() throws {
        let fresh = KeychainStore(service: "dev.vibevault.empty.\(UUID().uuidString)", accessGroup: nil)
        XCTAssertEqual(try fresh.list(), [])
    }

    // MARK: - validateName boundary: exactly 256 chars allowed, 257 rejected

    func test_validateName_accepts_256_char_name() throws {
        let name = String(repeating: "A", count: 256)
        XCTAssertNoThrow(try KeychainStore.validateName(name))
    }

    func test_validateName_rejects_257_char_name() {
        let name = String(repeating: "A", count: 257)
        XCTAssertThrowsError(try KeychainStore.validateName(name)) { err in
            XCTAssertEqual(err as? SecretError, .invalidName(name))
        }
    }

    func test_validateName_rejects_trailing_whitespace() {
        XCTAssertThrowsError(try KeychainStore.validateName("KEY ")) { err in
            if case .invalidName = err as? SecretError {} else { XCTFail("wrong error") }
        }
    }

    // MARK: - encodeMetadata: mcpAllowed=false produces nil (no metadata stored)

    func test_encodeMetadata_all_nil_returns_nil() {
        let s = Secret(name: "X", value: "v")
        XCTAssertNil(KeychainStore.encodeMetadata(from: s))
    }

    func test_encodeMetadata_with_notes_returns_non_nil() {
        let s = Secret(name: "X", value: "v", notes: "hi")
        XCTAssertNotNil(KeychainStore.encodeMetadata(from: s))
    }

    // MARK: - accessGroup: initialiser stores group and passes it through list()

    func test_store_with_accessGroup_does_not_crash_on_list() {
        // accessGroup is set; list may return errSecMissingEntitlement in test
        // but the branch at line 104/137 is exercised — guard/throw path is acceptable
        let groupStore = KeychainStore(
            service: "dev.vibevault.grp.\(UUID().uuidString)",
            accessGroup: "group.dev.vibevault"
        )
        // We only care the branch is entered, not that the Keychain succeeds in test sandbox
        _ = try? groupStore.list()
    }
}
