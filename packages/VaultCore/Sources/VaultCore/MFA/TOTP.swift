import CryptoKit
import Foundation

public enum TOTPAlgorithm: String, Codable, Equatable, Sendable {
    case sha1
    case sha256
    case sha512
}

public struct TOTPAccount: Equatable, Sendable {
    public let secret: Data
    public let issuer: String?
    public let account: String?
    public let digits: Int
    public let period: Int
    public let algorithm: TOTPAlgorithm
}

public struct TOTPCode: Equatable, Sendable {
    public let code: String
    public let secondsRemaining: Int
    public let period: Int
}

public enum TOTPError: Error, Equatable, CustomStringConvertible {
    case invalidSecret
    case invalidURL
    case unsupportedAlgorithm(String)
    case invalidParameter(String)

    public var description: String {
        switch self {
        case .invalidSecret: return "invalid MFA setup key"
        case .invalidURL: return "invalid otpauth URL"
        case .unsupportedAlgorithm(let value): return "unsupported MFA algorithm: \(value)"
        case .invalidParameter(let value): return "invalid MFA parameter: \(value)"
        }
    }
}

public enum TOTPGenerator {
    public static func account(from input: String) throws -> TOTPAccount {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw TOTPError.invalidSecret }
        if trimmed.lowercased().hasPrefix("otpauth://") {
            return try account(fromAuthURL: trimmed)
        }
        return TOTPAccount(
            secret: try decodeBase32(trimmed),
            issuer: nil,
            account: nil,
            digits: 6,
            period: 30,
            algorithm: .sha1
        )
    }

    public static func normalizedAuthURL(
        from input: String,
        label: String = "VibeVault",
        issuer: String? = nil
    ) throws -> String {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw TOTPError.invalidSecret }
        if trimmed.lowercased().hasPrefix("otpauth://") {
            _ = try account(from: trimmed)
            return trimmed
        }

        _ = try decodeBase32(trimmed)
        var components = URLComponents()
        components.scheme = "otpauth"
        components.host = "totp"
        components.path = "/\(label.isEmpty ? "VibeVault" : label)"
        var queryItems = [
            URLQueryItem(name: "secret", value: normalizedBase32(trimmed))
        ]
        if let issuer, !issuer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            queryItems.append(URLQueryItem(name: "issuer", value: issuer))
        }
        components.queryItems = queryItems
        guard let string = components.string else { throw TOTPError.invalidURL }
        return string
    }

    public static func code(from input: String, at date: Date = Date()) throws -> TOTPCode {
        try code(for: account(from: input), at: date)
    }

    public static func code(for account: TOTPAccount, at date: Date = Date()) throws -> TOTPCode {
        guard account.digits > 0, account.digits <= 10 else {
            throw TOTPError.invalidParameter("digits")
        }
        guard account.period > 0 else { throw TOTPError.invalidParameter("period") }

        let counter = UInt64(floor(date.timeIntervalSince1970 / Double(account.period)))
        var bigEndianCounter = counter.bigEndian
        let message = Data(bytes: &bigEndianCounter, count: MemoryLayout<UInt64>.size)
        let key = SymmetricKey(data: account.secret)
        let digest: Data
        switch account.algorithm {
        case .sha1:
            digest = Data(HMAC<Insecure.SHA1>.authenticationCode(for: message, using: key))
        case .sha256:
            digest = Data(HMAC<SHA256>.authenticationCode(for: message, using: key))
        case .sha512:
            digest = Data(HMAC<SHA512>.authenticationCode(for: message, using: key))
        }
        guard let last = digest.last else { throw TOTPError.invalidSecret }
        let offset = Int(last & 0x0f)
        guard offset + 3 < digest.count else { throw TOTPError.invalidSecret }
        let binary =
            ((Int(digest[offset]) & 0x7f) << 24) |
            ((Int(digest[offset + 1]) & 0xff) << 16) |
            ((Int(digest[offset + 2]) & 0xff) << 8) |
            (Int(digest[offset + 3]) & 0xff)
        let divisor = powerOfTen(account.digits)
        let numeric = binary % divisor
        let code = String(format: "%0\(account.digits)d", numeric)
        let elapsed = Int(date.timeIntervalSince1970) % account.period
        return TOTPCode(code: code, secondsRemaining: account.period - elapsed, period: account.period)
    }

    private static func account(fromAuthURL string: String) throws -> TOTPAccount {
        guard let components = URLComponents(string: string),
              components.scheme?.lowercased() == "otpauth",
              components.host?.lowercased() == "totp"
        else { throw TOTPError.invalidURL }
        var query: [String: String] = [:]
        for item in components.queryItems ?? [] {
            if let value = item.value {
                query[item.name.lowercased()] = value
            }
        }
        guard let secretText = query["secret"], !secretText.isEmpty else { throw TOTPError.invalidSecret }
        let algorithm = try parseAlgorithm(query["algorithm"])
        let digits = try parsePositiveInt(query["digits"], defaultValue: 6, name: "digits")
        let period = try parsePositiveInt(query["period"], defaultValue: 30, name: "period")
        let label = components.path.removingPercentEncoding?
            .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let issuerFromLabel: String?
        let accountFromLabel: String?
        if let label, let split = label.firstIndex(of: ":") {
            issuerFromLabel = String(label[..<split])
            accountFromLabel = String(label[label.index(after: split)...])
        } else {
            issuerFromLabel = nil
            accountFromLabel = label?.isEmpty == false ? label : nil
        }
        return TOTPAccount(
            secret: try decodeBase32(secretText),
            issuer: query["issuer"] ?? issuerFromLabel,
            account: accountFromLabel,
            digits: digits,
            period: period,
            algorithm: algorithm
        )
    }

    private static func parseAlgorithm(_ value: String?) throws -> TOTPAlgorithm {
        guard let value, !value.isEmpty else { return .sha1 }
        let normalized = value.lowercased().replacingOccurrences(of: "-", with: "")
        switch normalized {
        case "sha1": return .sha1
        case "sha256": return .sha256
        case "sha512": return .sha512
        default: throw TOTPError.unsupportedAlgorithm(value)
        }
    }

    private static func parsePositiveInt(_ value: String?, defaultValue: Int, name: String) throws -> Int {
        guard let value, !value.isEmpty else { return defaultValue }
        guard let parsed = Int(value), parsed > 0 else { throw TOTPError.invalidParameter(name) }
        return parsed
    }

    private static func decodeBase32(_ value: String) throws -> Data {
        let alphabet = Array("ABCDEFGHIJKLMNOPQRSTUVWXYZ234567")
        let lookup = Dictionary(uniqueKeysWithValues: alphabet.enumerated().map { ($0.element, $0.offset) })
        var buffer = 0
        var bitsLeft = 0
        var bytes: [UInt8] = []
        for char in normalizedBase32(value) {
            guard let decoded = lookup[char] else { throw TOTPError.invalidSecret }
            buffer = (buffer << 5) | decoded
            bitsLeft += 5
            if bitsLeft >= 8 {
                bitsLeft -= 8
                bytes.append(UInt8((buffer >> bitsLeft) & 0xff))
                buffer &= (1 << bitsLeft) - 1
            }
        }
        guard !bytes.isEmpty else { throw TOTPError.invalidSecret }
        return Data(bytes)
    }

    private static func normalizedBase32(_ value: String) -> String {
        value
            .uppercased()
            .components(separatedBy: .whitespacesAndNewlines)
            .joined()
            .replacingOccurrences(of: "=", with: "")
            .replacingOccurrences(of: "-", with: "")
    }

    private static func powerOfTen(_ exponent: Int) -> Int {
        var result = 1
        for _ in 0..<exponent { result *= 10 }
        return result
    }
}
