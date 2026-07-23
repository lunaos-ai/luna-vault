import XCTest
@testable import VaultCore

final class SecretValueGeneratorTests: XCTestCase {
    func test_hex_has_requested_length_and_alphabet() throws {
        let value = try SecretValueGenerator.generate(format: .hex, length: 63)

        XCTAssertEqual(value.count, 63)
        XCTAssertTrue(value.allSatisfy { $0.isHexDigit })
    }

    func test_base64_url_has_requested_length_and_alphabet() throws {
        let value = try SecretValueGenerator.generate(format: .base64URL, length: 48)
        let allowed = CharacterSet(charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_")

        XCTAssertEqual(value.count, 48)
        XCTAssertTrue(value.unicodeScalars.allSatisfy { allowed.contains($0) })
    }

    func test_base64_has_requested_length_and_alphabet() throws {
        let value = try SecretValueGenerator.generate(format: .base64, length: 52)
        let allowed = CharacterSet(charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/")

        XCTAssertEqual(value.count, 52)
        XCTAssertTrue(value.unicodeScalars.allSatisfy { allowed.contains($0) })
    }

    func test_password_has_requested_length_without_whitespace() throws {
        let value = try SecretValueGenerator.generate(format: .password, length: 40)

        XCTAssertEqual(value.count, 40)
        XCTAssertFalse(value.contains { $0.isWhitespace })
    }

    func test_uuid_is_parseable_uuid() throws {
        let value = try SecretValueGenerator.generate(format: .uuid, length: 128)

        XCTAssertEqual(value.count, 36)
        XCTAssertNotNil(UUID(uuidString: value))
    }

    func test_prefixed_token_has_prefix_and_requested_length() throws {
        let value = try SecretValueGenerator.generate(format: .prefixedToken, length: 36)

        XCTAssertEqual(value.count, 36)
        XCTAssertTrue(value.hasPrefix("vv_"))
    }

    func test_lengths_are_clamped_to_format_ranges() throws {
        let shortHex = try SecretValueGenerator.generate(format: .hex, length: 4)
        let longToken = try SecretValueGenerator.generate(format: .prefixedToken, length: 400)

        XCTAssertEqual(shortHex.count, 16)
        XCTAssertEqual(longToken.count, 128)
    }
}
