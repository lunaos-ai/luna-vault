import XCTest
@testable import VaultCore

final class KeychainPrefsTests: XCTestCase {

    func test_inMemory_roundTrip_data() {
        let prefs = InMemoryPrefs()
        XCTAssertNil(prefs.data(forKey: "k"))
        prefs.set(Data([1, 2, 3]), forKey: "k")
        XCTAssertEqual(prefs.data(forKey: "k"), Data([1, 2, 3]))
        prefs.set(nil, forKey: "k")
        XCTAssertNil(prefs.data(forKey: "k"))
    }

    func test_codable_roundTrip() {
        struct S: Codable, Equatable { var a: Int; var b: String }
        let prefs = InMemoryPrefs()
        let v = S(a: 7, b: "hi")
        prefs.setCodable(v, forKey: "obj")
        XCTAssertEqual(prefs.codable(S.self, forKey: "obj"), v)
        prefs.setCodable(Optional<S>.none, forKey: "obj")
        XCTAssertNil(prefs.codable(S.self, forKey: "obj"))
    }

    func test_missingKey_returnsNil() {
        let prefs = InMemoryPrefs()
        XCTAssertNil(prefs.codable([String].self, forKey: "missing"))
    }

    func test_removeAll_clears() {
        let prefs = InMemoryPrefs()
        prefs.set(Data([1]), forKey: "a")
        prefs.set(Data([2]), forKey: "b")
        prefs.removeAll()
        XCTAssertNil(prefs.data(forKey: "a"))
        XCTAssertNil(prefs.data(forKey: "b"))
    }
}
