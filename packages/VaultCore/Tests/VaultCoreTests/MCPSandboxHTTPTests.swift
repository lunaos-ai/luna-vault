import XCTest
@testable import VaultCore

final class HTTPRequestParserTests: XCTestCase {
    func test_parses_post_with_bearer_and_body() {
        let raw = Data("POST /mcp HTTP/1.1\r\nAuthorization: Bearer tok\r\nContent-Length: 2\r\n\r\n{}".utf8)
        switch HTTPRequestParser.parse(raw) {
        case .complete(let request):
            XCTAssertEqual(request.method, "POST")
            XCTAssertEqual(request.path, "/mcp")
            XCTAssertEqual(request.header("authorization"), "Bearer tok")
            XCTAssertEqual(request.body, Data("{}".utf8))
        default:
            XCTFail("expected complete request")
        }
    }

    func test_incomplete_until_body_arrives() {
        let headers = Data("POST /mcp HTTP/1.1\r\nContent-Length: 4\r\n\r\nab".utf8)
        XCTAssertEqual(HTTPRequestParser.parse(headers), .incomplete)
        let full = Data("POST /mcp HTTP/1.1\r\nContent-Length: 4\r\n\r\nabcd".utf8)
        if case .complete(let request) = HTTPRequestParser.parse(full) {
            XCTAssertEqual(request.body, Data("abcd".utf8))
        } else {
            XCTFail("expected complete")
        }
    }

    func test_health_get_without_body() {
        let raw = Data("GET /health HTTP/1.1\r\nHost: 127.0.0.1\r\n\r\n".utf8)
        if case .complete(let request) = HTTPRequestParser.parse(raw) {
            XCTAssertEqual(request.method, "GET")
            XCTAssertEqual(request.path, "/health")
            XCTAssertTrue(request.body.isEmpty)
        } else {
            XCTFail("expected complete")
        }
    }
}

final class MCPSandboxHTTPRouterTests: XCTestCase {
    func test_health_does_not_require_auth() async {
        let request = HTTPRequest(method: "GET", path: "/health", headers: [:], body: Data())
        let response = await MCPSandboxHTTPRouter.route(request, prefs: InMemoryPrefs()) { _ in Data() }
        XCTAssertEqual(response.status, 200)
        XCTAssertEqual(String(data: response.body, encoding: .utf8), #"{"ok":true}"#)
    }

    func test_mcp_post_without_auth_is_401() async {
        let request = HTTPRequest(method: "POST", path: "/mcp", headers: [:], body: Data("{}".utf8))
        let response = await MCPSandboxHTTPRouter.route(request, prefs: InMemoryPrefs()) { _ in Data() }
        XCTAssertEqual(response.status, 401)
    }

    func test_bearer_token_reaches_handler() async throws {
        let prefs = InMemoryPrefs()
        try MCPSandboxPasskeyStore(prefs: prefs).enroll("correct horse battery")
        let token = try MCPSandboxTokenMint.mint(minutes: 30, prefs: prefs)
        let request = HTTPRequest(
            method: "POST",
            path: "/mcp",
            headers: ["authorization": "Bearer \(token.value)"],
            body: Data("{\"jsonrpc\":\"2.0\"}".utf8)
        )
        let response = await MCPSandboxHTTPRouter.route(request, prefs: prefs) { body in
            XCTAssertEqual(body, Data("{\"jsonrpc\":\"2.0\"}".utf8))
            return Data("{\"ok\":1}".utf8)
        }
        XCTAssertEqual(response.status, 200)
        XCTAssertEqual(String(data: response.body, encoding: .utf8), "{\"ok\":1}")
    }

    func test_passkey_header_authorizes() async throws {
        let prefs = InMemoryPrefs()
        try MCPSandboxPasskeyStore(prefs: prefs).enroll("correct horse battery")
        let request = HTTPRequest(
            method: "POST",
            path: "/mcp",
            headers: ["authorization": "Passkey correct horse battery"],
            body: Data("{}".utf8)
        )
        let response = await MCPSandboxHTTPRouter.route(request, prefs: prefs) { _ in Data("[]".utf8) }
        XCTAssertEqual(response.status, 200)
    }

    func test_launch_args_detect_http_port() {
        XCTAssertNil(MCPHTTPLaunchArgs.portIfHTTP(arguments: ["vibevault-mcp"], environment: [:]))
        XCTAssertEqual(
            MCPHTTPLaunchArgs.portIfHTTP(arguments: ["vibevault-mcp", "--http"], environment: [:]),
            17_832
        )
        XCTAssertEqual(
            MCPHTTPLaunchArgs.portIfHTTP(
                arguments: ["vibevault-mcp", "--http", "--port", "9999"],
                environment: [:]
            ),
            9999
        )
        XCTAssertEqual(
            MCPHTTPLaunchArgs.portIfHTTP(
                arguments: ["vibevault-mcp"],
                environment: ["VIBEVAULT_MCP_HTTP": "1", "VIBEVAULT_MCP_PORT": "18000"]
            ),
            18_000
        )
    }
}

final class MCPClientHTTPInstallerTests: XCTestCase {
    func test_http_config_writes_url_and_bearer() throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("vv-mcp-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let url = dir.appendingPathComponent("mcp.json")
        defer { try? FileManager.default.removeItem(at: dir) }
        try MCPClientInstaller.installHTTP(
            at: url,
            client: .cursor,
            url: "http://127.0.0.1:17832/mcp",
            bearerToken: "tok-1"
        )
        let json = try JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any]
        let server = (json?["mcpServers"] as? [String: Any])?["vibe-vault"] as? [String: Any]
        XCTAssertEqual(server?["url"] as? String, "http://127.0.0.1:17832/mcp")
        XCTAssertEqual(server?["type"] as? String, "http")
        let headers = server?["headers"] as? [String: String]
        XCTAssertEqual(headers?["Authorization"], "Bearer tok-1")
    }
}
