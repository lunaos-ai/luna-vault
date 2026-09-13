import Foundation

public struct HTTPRequest: Equatable, Sendable {
    public let method: String
    public let path: String
    public let headers: [String: String]
    public let body: Data

    public init(method: String, path: String, headers: [String: String], body: Data) {
        self.method = method
        self.path = path
        self.headers = headers
        self.body = body
    }

    public func header(_ name: String) -> String? {
        headers[name.lowercased()]
    }
}

public struct HTTPResponse: Equatable, Sendable {
    public var status: Int
    public var reason: String
    public var headers: [String: String]
    public var body: Data

    public init(status: Int, reason: String, headers: [String: String] = [:], body: Data = Data()) {
        self.status = status
        self.reason = reason
        self.headers = headers
        self.body = body
    }

    public static func json(_ status: Int, reason: String, utf8: String) -> HTTPResponse {
        let data = Data(utf8.utf8)
        return HTTPResponse(
            status: status,
            reason: reason,
            headers: [
                "Content-Type": "application/json",
                "Content-Length": "\(data.count)"
            ],
            body: data
        )
    }

    public static let unauthorized = HTTPResponse(
        status: 401,
        reason: "Unauthorized",
        headers: ["WWW-Authenticate": "Bearer, Passkey"],
        body: Data("unauthorized\n".utf8)
    )

    public func encode() -> Data {
        var headerMap = headers
        headerMap["Content-Length"] = "\(body.count)"
        headerMap["Connection"] = "close"
        var header = "HTTP/1.1 \(status) \(reason)\r\n"
        for (key, value) in headerMap.sorted(by: { $0.key < $1.key }) {
            header += "\(key): \(value)\r\n"
        }
        header += "\r\n"
        var data = Data(header.utf8)
        data.append(body)
        return data
    }
}
