import Foundation

public struct Secret: Equatable, Hashable, Sendable {
    public let name: String
    public let value: String
    public let updatedAt: Date
    public let notes: String?

    public init(name: String, value: String, updatedAt: Date = Date(), notes: String? = nil) {
        self.name = name
        self.value = value
        self.updatedAt = updatedAt
        self.notes = notes
    }

    public var maskedValue: String {
        guard value.count > 8 else { return String(repeating: "•", count: max(value.count, 4)) }
        let prefix = value.prefix(3)
        let suffix = value.suffix(4)
        return "\(prefix)…\(suffix)"
    }
}

public enum SecretError: Error, Equatable {
    case notFound(name: String)
    case duplicate(name: String)
    case keychainStatus(Int32)
    case biometricDenied
    case invalidName(String)
}

extension SecretError: CustomStringConvertible {
    public var description: String {
        switch self {
        case .notFound(let n): return "secret not found: \(n)"
        case .duplicate(let n): return "secret already exists: \(n)"
        case .keychainStatus(let s): return "keychain error: OSStatus \(s)"
        case .biometricDenied: return "biometric authentication denied"
        case .invalidName(let n): return "invalid secret name: \(n)"
        }
    }
}
