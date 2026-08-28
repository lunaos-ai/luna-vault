import XCTest
@testable import VaultCore

final class PlatformSupportTests: XCTestCase {
    func testHostIsRecognized() {
        #if os(macOS)
        XCTAssertEqual(PlatformSupport.host, .macOS)
        XCTAssertTrue(PlatformSupport.hasNativeApp)
        XCTAssertTrue(PlatformSupport.hasAppleKeychain)
        #elseif os(Linux)
        XCTAssertEqual(PlatformSupport.host, .linux)
        XCTAssertFalse(PlatformSupport.hasNativeApp)
        XCTAssertFalse(PlatformSupport.hasAppleKeychain)
        #elseif os(Windows)
        XCTAssertEqual(PlatformSupport.host, .windows)
        XCTAssertFalse(PlatformSupport.hasNativeApp)
        #endif
    }

    func testDataDirectoryHintIsNonEmpty() {
        XCTAssertFalse(PlatformSupport.dataDirectoryHint.isEmpty)
    }

    func testPlatformRandomProducesKeyMaterial() throws {
        let bytes = try PlatformRandom.bytes(count: 32)
        XCTAssertEqual(bytes.count, 32)
        let key = try PlatformRandom.symmetricKey()
        XCTAssertEqual(key.bitCount, 256)
    }
}
