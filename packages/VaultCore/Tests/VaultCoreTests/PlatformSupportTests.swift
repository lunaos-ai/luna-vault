import XCTest
@testable import VaultCore

final class PlatformSupportTests: XCTestCase {
    func testHostIsRecognized() {
        #if os(macOS)
        XCTAssertEqual(PlatformSupport.host, .macOS)
        XCTAssertTrue(PlatformSupport.hasNativeApp)
        XCTAssertTrue(PlatformSupport.hasAppleKeychain)
        XCTAssertEqual(PlatformSupport.masterKeyBackend, .appleKeychain)
        #elseif os(Linux)
        XCTAssertEqual(PlatformSupport.host, .linux)
        XCTAssertTrue(PlatformSupport.hasNativeApp)
        XCTAssertFalse(PlatformSupport.hasAppleKeychain)
        XCTAssertEqual(PlatformSupport.masterKeyBackend, .linuxSecretService)
        #elseif os(Windows)
        XCTAssertEqual(PlatformSupport.host, .windows)
        XCTAssertTrue(PlatformSupport.hasNativeApp)
        XCTAssertFalse(PlatformSupport.hasAppleKeychain)
        XCTAssertEqual(PlatformSupport.masterKeyBackend, .windowsDPAPI)
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
