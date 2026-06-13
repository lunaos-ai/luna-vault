import XCTest
@testable import VaultCore

final class SecretHistoryStoreTests: XCTestCase {
    func testRecordsNewestFirst() throws {
        let h = InMemoryHistoryStore()
        try h.record(name: "API", value: "v1", at: Date(timeIntervalSince1970: 1))
        try h.record(name: "API", value: "v2", at: Date(timeIntervalSince1970: 2))
        let v = try h.versions(name: "API")
        XCTAssertEqual(v.map(\.value), ["v2", "v1"])
    }

    func testDedupesUnchangedValue() throws {
        let h = InMemoryHistoryStore()
        try h.record(name: "API", value: "same")
        try h.record(name: "API", value: "same")
        XCTAssertEqual(try h.versions(name: "API").count, 1)
    }

    func testCapsToLimit() throws {
        let h = InMemoryHistoryStore(limit: 3)
        for i in 0..<6 { try h.record(name: "API", value: "v\(i)") }
        let v = try h.versions(name: "API")
        XCTAssertEqual(v.count, 3)
        XCTAssertEqual(v.first?.value, "v5")
    }

    func testClear() throws {
        let h = InMemoryHistoryStore()
        try h.record(name: "API", value: "v1")
        try h.clear(name: "API")
        XCTAssertTrue(try h.versions(name: "API").isEmpty)
    }

    func testVersionMasksValue() {
        XCTAssertEqual(SecretVersion(value: "supersecretvalue").maskedValue, "sup…alue")
    }

    func testUnknownNameReturnsEmpty() throws {
        XCTAssertTrue(try InMemoryHistoryStore().versions(name: "nope").isEmpty)
    }
}
