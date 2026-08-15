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
    case temporaryCode
    case unsupportedAlgorithm(String)
    case invalidParameter(String)

    public var description: String {
        switch self {
        case .invalidSecret: return "invalid MFA setup key"
        case .invalidURL: return "invalid otpauth URL"
        case .temporaryCode: return "this is a temporary code; use the setup key or QR code"
        case .unsupportedAlgorithm(let value): return "unsupported MFA algorithm: \(value)"
        case .invalidParameter(let value): return "invalid MFA parameter: \(value)"
        }
    }
}
