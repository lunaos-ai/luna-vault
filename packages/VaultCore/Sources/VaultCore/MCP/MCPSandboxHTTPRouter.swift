import Foundation

public enum MCPSandboxHTTPAuth {
    public static func isAuthorized(
        _ request: HTTPRequest,
        prefs: PreferenceStoring,
        now: Date = Date()
    ) -> Bool {
        guard let raw = request.header("authorization") else { return false }
        let value = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        let lower = value.lowercased()
        if lower.hasPrefix("bearer ") {
            let token = String(value.dropFirst(7)).trimmingCharacters(in: .whitespaces)
            return MCPSandboxTokenMint.validate(token, prefs: prefs, now: now)
        }
        if lower.hasPrefix("passkey ") {
            let passkey = String(value.dropFirst(8))
            return (try? MCPSandboxPasskeyStore(prefs: prefs).verify(passkey)) == true
        }
        return false
    }
}

public enum MCPSandboxHTTPRouter {
    public static func route(
        _ request: HTTPRequest,
        prefs: PreferenceStoring,
        now: Date = Date(),
        handleMCP: (Data) async -> Data
    ) async -> HTTPResponse {
        let path = request.path.split(separator: "?").first.map(String.init) ?? request.path
        if request.method == "GET" && path == "/health" {
            return HTTPResponse.json(200, reason: "OK", utf8: #"{"ok":true}"#)
        }
        if request.method == "OPTIONS" && path == "/mcp" {
            return HTTPResponse(
                status: 204,
                reason: "No Content",
                headers: [
                    "Access-Control-Allow-Origin": "*",
                    "Access-Control-Allow-Headers": "Authorization, Content-Type",
                    "Access-Control-Allow-Methods": "POST, OPTIONS"
                ]
            )
        }
        guard path == "/mcp" else {
            return HTTPResponse(status: 404, reason: "Not Found", body: Data("not found\n".utf8))
        }
        guard request.method == "POST" else {
            return HTTPResponse(status: 405, reason: "Method Not Allowed", body: Data("method not allowed\n".utf8))
        }
        guard MCPSandboxHTTPAuth.isAuthorized(request, prefs: prefs, now: now) else {
            return .unauthorized
        }
        let payload = await handleMCP(request.body)
        if payload.isEmpty {
            return HTTPResponse(status: 202, reason: "Accepted")
        }
        return HTTPResponse(
            status: 200,
            reason: "OK",
            headers: ["Content-Type": "application/json"],
            body: payload
        )
    }
}
