import XCTest
@testable import VaultCore

final class KeychainStoreTests: XCTestCase {
    private var store: KeychainStore!
    private var serviceName: String!

    override func setUpWithError() throws {
        serviceName = "dev.vibevault.test.\(UUID().uuidString)"
        store = KeychainStore(service: serviceName)
    }

    override func tearDownWithError() throws {
        for secret in (try? store.list()) ?? [] {
            try? store.delete(name: secret.name)
        }
    }

    func test_add_then_read_returns_value() throws {
        try store.add(Secret(name: "TEST_TOKEN", value: "abc123"))
        let read = try store.read(name: "TEST_TOKEN")
        XCTAssertEqual(read.value, "abc123")
    }

    func test_add_duplicate_throws() throws {
        try store.add(Secret(name: "DUP", value: "v1"))
        XCTAssertThrowsError(try store.add(Secret(name: "DUP", value: "v2"))) { error in
            XCTAssertEqual(error as? SecretError, SecretError.duplicate(name: "DUP"))
        }
    }

    func test_update_changes_value() throws {
        try store.add(Secret(name: "UPD", value: "v1"))
        try store.update(Secret(name: "UPD", value: "v2"))
        XCTAssertEqual(try store.read(name: "UPD").value, "v2")
    }

    func test_delete_then_read_throws_notFound() throws {
        try store.add(Secret(name: "DEL", value: "x"))
        try store.delete(name: "DEL")
        XCTAssertThrowsError(try store.read(name: "DEL"))
    }

    func test_list_returns_all_added() throws {
        try store.add(Secret(name: "A", value: "1"))
        try store.add(Secret(name: "B", value: "2"))
        let names = Set(try store.list().map(\.name))
        XCTAssertEqual(names, Set(["A", "B"]))
    }

    func test_validateName_rejects_invalid() {
        XCTAssertThrowsError(try KeychainStore.validateName(""))
        XCTAssertThrowsError(try KeychainStore.validateName(" leading"))
        XCTAssertThrowsError(try KeychainStore.validateName("has space"))
        XCTAssertThrowsError(try KeychainStore.validateName("emoji-\u{1F600}"))
        XCTAssertNoThrow(try KeychainStore.validateName("VALID_NAME"))
        XCTAssertNoThrow(try KeychainStore.validateName("dotted.name-1"))
    }

    func test_maskedValue_format() {
        let s = Secret(name: "X", value: "supersecrettoken12345")
        XCTAssertEqual(s.maskedValue, "sup…2345")
    }
}
