import Foundation

public struct Secret: Equatable, Hashable, Sendable {
    public let name: String
    public let value: String
    public let updatedAt: Date
    public let notes: String?
    public let expiresAt: Date?
    public let rotateEveryDays: Int?
    public let lastRotatedAt: Date?
    public let mcpAllowed: Bool

    public init(
        name: String,
        value: String,
        updatedAt: Date = Date(),
        notes: String? = nil,
        expiresAt: Date? = nil,
        rotateEveryDays: Int? = nil,
        lastRotatedAt: Date? = nil,
        mcpAllowed: Bool = false
    ) {
        self.name = name
        self.value = value
        self.updatedAt = updatedAt
        self.notes = notes
        self.expiresAt = expiresAt
        self.rotateEveryDays = rotateEveryDays
        self.lastRotatedAt = lastRotatedAt
        self.mcpAllowed = mcpAllowed
    }

    public var maskedValue: String {
        guard value.count > 8 else { return String(repeating: "•", count: max(value.count, 4)) }
        let prefix = value.prefix(3)
        let suffix = value.suffix(4)
        return "\(prefix)…\(suffix)"
    }

    public var isExpired: Bool {
        guard let exp = expiresAt else { return false }
        return Date() >= exp
    }

    public var rotationDueAt: Date? {
        guard let every = rotateEveryDays, every > 0 else { return nil }
        let base = lastRotatedAt ?? updatedAt
        return Calendar.current.date(byAdding: .day, value: every, to: base)
    }

    public var isRotationDue: Bool {
        guard let due = rotationDueAt else { return false }
        return Date() >= due
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

/// JSON-encoded into kSecAttrComment alongside the secret in Keychain.
struct SecretMetadata: Codable {
    var notes: String?
    var expiresAt: Date?
    var rotateEveryDays: Int?
    var lastRotatedAt: Date?
    var mcpAllowed: Bool?

    static let empty = SecretMetadata()

    static func decode(_ string: String?) -> SecretMetadata {
        guard let s = string, !s.isEmpty, let data = s.data(using: .utf8) else { return .empty }
        if let parsed = try? JSONDecoder.luna.decode(SecretMetadata.self, from: data) { return parsed }
        return SecretMetadata(notes: s)
    }

    func encode() -> String? {
        if notes == nil, expiresAt == nil, rotateEveryDays == nil,
           lastRotatedAt == nil, mcpAllowed == nil { return nil }
        guard let data = try? JSONEncoder.luna.encode(self),
              let s = String(data: data, encoding: .utf8) else { return nil }
        return s
    }
}

extension JSONEncoder {
    static let luna: JSONEncoder = {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        return e
    }()
}

extension JSONDecoder {
    static let luna: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()
}
