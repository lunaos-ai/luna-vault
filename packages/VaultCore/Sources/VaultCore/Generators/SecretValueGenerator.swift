import Foundation
import Security

public enum SecretValueFormat: String, CaseIterable, Identifiable, Sendable {
    case hex
    case base64URL
    case base64
    case password
    case uuid
    case prefixedToken

    public var id: String { rawValue }

    public var label: String {
        switch self {
        case .hex:
            "Hex"
        case .base64URL:
            "Base64 URL"
        case .base64:
            "Base64"
        case .password:
            "Password"
        case .uuid:
            "UUID"
        case .prefixedToken:
            "Prefixed token"
        }
    }

    public var defaultLength: Int {
        switch self {
        case .hex:
            64
        case .base64URL, .base64, .prefixedToken:
            48
        case .password:
            32
        case .uuid:
            36
        }
    }

    public var lengthRange: ClosedRange<Int>? {
        switch self {
        case .uuid:
            nil
        case .prefixedToken:
            12...128
        case .hex, .base64URL, .base64, .password:
            16...128
        }
    }

    public var usesLength: Bool {
        lengthRange != nil
    }

    public func clampedLength(_ length: Int) -> Int {
        guard let lengthRange else { return defaultLength }
        return min(max(length, lengthRange.lowerBound), lengthRange.upperBound)
    }
}

public enum SecretValueGeneratorError: Error, Equatable, LocalizedError {
    case randomBytesUnavailable(OSStatus)

    public var errorDescription: String? {
        switch self {
        case .randomBytesUnavailable:
            "Could not read secure random bytes."
        }
    }
}

public enum SecretValueGenerator {
    private static let base64URLAlphabet = Array("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_")
    private static let base64Alphabet = Array("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/")
    private static let passwordAlphabet = Array("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789._-+=@#%:~")

    public static func generate(format: SecretValueFormat, length requestedLength: Int? = nil, prefix requestedPrefix: String? = nil) throws -> String {
        switch format {
        case .hex:
            let length = format.clampedLength(requestedLength ?? format.defaultLength)
            return try hex(length: length)
        case .base64URL:
            let length = format.clampedLength(requestedLength ?? format.defaultLength)
            return try randomString(length: length, alphabet: base64URLAlphabet)
        case .base64:
            let length = format.clampedLength(requestedLength ?? format.defaultLength)
            return try randomString(length: length, alphabet: base64Alphabet)
        case .password:
            let length = format.clampedLength(requestedLength ?? format.defaultLength)
            return try randomString(length: length, alphabet: passwordAlphabet)
        case .uuid:
            return UUID().uuidString
        case .prefixedToken:
            let length = format.clampedLength(requestedLength ?? format.defaultLength)
            let prefix = normalizedPrefix(requestedPrefix)
            let tokenPrefix = "\(prefix)_"
            let suffixLength = max(8, length - tokenPrefix.count)
            let suffix = try randomString(length: suffixLength, alphabet: base64URLAlphabet)
            return tokenPrefix + suffix
        }
    }

    public static func normalizedPrefix(_ requestedPrefix: String?) -> String {
        let raw = (requestedPrefix ?? "vv").trimmingCharacters(in: .whitespacesAndNewlines)
        let cleaned = raw
            .lowercased()
            .map { char -> Character in
                if char.isLetter || char.isNumber { return char }
                if char == "_" || char == "-" { return char }
                return "_"
            }
        let joined = String(cleaned)
            .split(separator: "_")
            .joined(separator: "_")
            .trimmingCharacters(in: CharacterSet(charactersIn: "_-"))
        return joined.isEmpty ? "vv" : String(joined.prefix(24))
    }

    private static func hex(length: Int) throws -> String {
        let byteCount = (length + 1) / 2
        let bytes = try randomBytes(count: byteCount)
        let encoded = bytes.map { String(format: "%02x", $0) }.joined()
        return String(encoded.prefix(length))
    }

    private static func randomString(length: Int, alphabet: [Character]) throws -> String {
        let alphabetCount = alphabet.count
        let acceptanceLimit = 256 - (256 % alphabetCount)
        var output = ""
        output.reserveCapacity(length)

        while output.count < length {
            let bytes = try randomBytes(count: max(32, length))
            for byte in bytes where Int(byte) < acceptanceLimit {
                output.append(alphabet[Int(byte) % alphabetCount])
                if output.count == length {
                    return output
                }
            }
        }

        return output
    }

    private static func randomBytes(count: Int) throws -> [UInt8] {
        var bytes = [UInt8](repeating: 0, count: count)
        let status = bytes.withUnsafeMutableBytes { buffer in
            SecRandomCopyBytes(kSecRandomDefault, count, buffer.baseAddress!)
        }

        guard status == errSecSuccess else {
            throw SecretValueGeneratorError.randomBytesUnavailable(status)
        }

        return bytes
    }
}
