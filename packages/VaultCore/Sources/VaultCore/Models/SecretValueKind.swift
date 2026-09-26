import Foundation

/// How the secret value should be stored and shown.
public enum SecretValueKind: String, Codable, Sendable, Hashable, CaseIterable {
    case text
    case json

    public var label: String {
        switch self {
        case .text: return "Text"
        case .json: return "JSON"
        }
    }
}
