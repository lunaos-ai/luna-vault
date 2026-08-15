import Foundation

struct BrowserImportRequest: Decodable {
    let type: String
    let name: String?
    let value: String?
    let provider: String?
    let sourceUrl: String?
    let overwrite: Bool?
    let mcpAllowed: Bool?
    let otpauthURI: String?
}

struct BrowserImportResponse: Encodable {
    let ok: Bool
    let name: String?
    let error: String?
    let code: String?
    let version: String?

    static func success(name: String) -> BrowserImportResponse {
        BrowserImportResponse(ok: true, name: name, error: nil, code: nil, version: nil)
    }

    static func pong() -> BrowserImportResponse {
        BrowserImportResponse(ok: true, name: nil, error: nil, code: nil, version: "0.1.0")
    }

    static func failure(_ error: String, code: String = "host_error") -> BrowserImportResponse {
        BrowserImportResponse(ok: false, name: nil, error: error, code: code, version: nil)
    }
}

enum BrowserHostError: Error, CustomStringConvertible {
    case invalidType
    case invalidName
    case invalidValue
    case duplicate(String)
    case oversizedMessage
    case incompleteMessage
    case invalidAuthenticator

    var description: String {
        switch self {
        case .invalidType: return "unsupported browser host request"
        case .invalidName: return "invalid secret name"
        case .invalidValue: return "invalid secret value"
        case .duplicate(let name): return "secret '\(name)' already exists"
        case .oversizedMessage: return "native message is too large"
        case .incompleteMessage: return "incomplete native message"
        case .invalidAuthenticator: return "invalid authenticator setup"
        }
    }
}
