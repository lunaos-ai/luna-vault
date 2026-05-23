import Foundation

enum MCP {
    static let protocolVersion = "2024-11-05"
    static let serverName = "vibe-vault"
    static let serverVersion = "0.1.0"
}

struct JSONRPCRequest: Decodable {
    let jsonrpc: String
    let id: JSONRPCID?
    let method: String
    let params: AnyCodable?
}

struct JSONRPCResponse: Encodable {
    let jsonrpc = "2.0"
    let id: JSONRPCID
    let result: AnyCodable?
    let error: JSONRPCError?
}

struct JSONRPCNotification: Encodable {
    let jsonrpc = "2.0"
    let method: String
    let params: AnyCodable?
}

struct JSONRPCError: Encodable {
    let code: Int
    let message: String
    var data: AnyCodable?

    static func methodNotFound(_ method: String) -> JSONRPCError {
        JSONRPCError(code: -32601, message: "Method not found: \(method)")
    }
    static func invalidParams(_ msg: String) -> JSONRPCError {
        JSONRPCError(code: -32602, message: "Invalid params: \(msg)")
    }
    static func internalError(_ msg: String) -> JSONRPCError {
        JSONRPCError(code: -32603, message: "Internal error: \(msg)")
    }
}

enum JSONRPCID: Codable, Hashable {
    case int(Int)
    case string(String)

    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if let i = try? c.decode(Int.self) { self = .int(i); return }
        if let s = try? c.decode(String.self) { self = .string(s); return }
        throw DecodingError.typeMismatch(JSONRPCID.self, .init(codingPath: decoder.codingPath, debugDescription: "id must be int or string"))
    }
    func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        switch self {
        case .int(let i): try c.encode(i)
        case .string(let s): try c.encode(s)
        }
    }
}

/// Type-erased JSON value, since MCP request params and tool args are open-shape.
struct AnyCodable: Codable {
    let value: Any
    init(_ value: Any) { self.value = value }
    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if c.decodeNil() { self.value = NSNull(); return }
        if let b = try? c.decode(Bool.self) { self.value = b; return }
        if let i = try? c.decode(Int.self) { self.value = i; return }
        if let d = try? c.decode(Double.self) { self.value = d; return }
        if let s = try? c.decode(String.self) { self.value = s; return }
        if let a = try? c.decode([AnyCodable].self) { self.value = a.map(\.value); return }
        if let o = try? c.decode([String: AnyCodable].self) {
            self.value = o.mapValues(\.value); return
        }
        self.value = NSNull()
    }
    func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        switch value {
        case is NSNull: try c.encodeNil()
        case let b as Bool: try c.encode(b)
        case let i as Int: try c.encode(i)
        case let d as Double: try c.encode(d)
        case let s as String: try c.encode(s)
        case let a as [Any]: try c.encode(a.map { AnyCodable($0) })
        case let o as [String: Any]: try c.encode(o.mapValues { AnyCodable($0) })
        default: try c.encodeNil()
        }
    }
    func asObject() -> [String: Any]? { value as? [String: Any] }
    func asString() -> String? { value as? String }
}
