import Foundation

public enum HTTPRequestParseResult: Equatable, Sendable {
    case incomplete
    case invalid
    case complete(HTTPRequest)
}

public enum HTTPRequestParser {
    private static let headerSeparator = Data("\r\n\r\n".utf8)

    public static func parse(_ data: Data) -> HTTPRequestParseResult {
        guard let range = data.range(of: headerSeparator) else {
            if data.count > MCPSandboxSettings.maxHTTPHeaderBytes { return .invalid }
            return .incomplete
        }
        let headerData = data[..<range.lowerBound]
        guard let headerText = String(data: headerData, encoding: .utf8) else { return .invalid }
        let lines = headerText.split(separator: "\r\n", omittingEmptySubsequences: false).map(String.init)
        guard let requestLine = lines.first else { return .invalid }
        let parts = requestLine.split(separator: " ", omittingEmptySubsequences: true).map(String.init)
        guard parts.count >= 2 else { return .invalid }
        var headers: [String: String] = [:]
        for line in lines.dropFirst() {
            guard let colon = line.firstIndex(of: ":") else { continue }
            let name = String(line[..<colon]).trimmingCharacters(in: .whitespaces).lowercased()
            let value = String(line[line.index(after: colon)...]).trimmingCharacters(in: .whitespaces)
            headers[name] = value
        }
        let length = Int(headers["content-length"] ?? "0") ?? 0
        guard length >= 0, length <= MCPSandboxSettings.maxHTTPBodyBytes else { return .invalid }
        let bodyStart = range.upperBound
        let available = data.count - bodyStart
        if available < length { return .incomplete }
        let body = data.subdata(in: bodyStart..<(bodyStart + length))
        return .complete(HTTPRequest(method: parts[0].uppercased(), path: parts[1], headers: headers, body: body))
    }
}
