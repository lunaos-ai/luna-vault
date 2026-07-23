import XCTest
@testable import VaultCore

final class WranglerConfigTests: XCTestCase {
    func test_parses_name_and_account_id() {
        let cfg = WranglerConfig.parse(content: """
        name = "my-worker"
        account_id = "abc123"
        compatibility_date = "2024-01-01"
        """)
        XCTAssertEqual(cfg.scriptName, "my-worker")
        XCTAssertEqual(cfg.accountId, "abc123")
        XCTAssertTrue(cfg.isComplete)
    }

    func test_scope_dictionary() {
        let cfg = WranglerConfig(scriptName: "w", accountId: "a")
        XCTAssertEqual(cfg.scope["script_name"], "w")
        XCTAssertEqual(cfg.scope["account_id"], "a")
    }

    func test_parses_jsonc_config_with_comments_and_trailing_commas() {
        let cfg = WranglerConfig.parse(content: """
        {
          // production worker
          "name": "vibevault",
          "account_id": "abc123",
          "compatibility_date": "2026-07-18",
        }
        """, filename: "wrangler.jsonc")

        XCTAssertEqual(cfg.scriptName, "vibevault")
        XCTAssertEqual(cfg.accountId, "abc123")
    }

    func test_toml_parser_handles_inline_comments() {
        let cfg = WranglerConfig.parse(content: """
        name = "my-worker" # visible in Cloudflare
        account_id = "abc123" # dashboard account
        """)

        XCTAssertEqual(cfg.scriptName, "my-worker")
        XCTAssertEqual(cfg.accountId, "abc123")
    }
}

final class CloudflareProviderTests: XCTestCase {
    override func setUp() {
        super.setUp()
        MockCFProtocol.handler = nil
        MockCFProtocol.requests = []
        MockCFProtocol.bodies = []
    }

    func test_missing_token_throws() {
        let provider = CloudflareProvider(tokenSource: { nil })
        XCTAssertThrowsError(try provider.authToken())
    }

    func test_auth_token_reads_alternate_cloudflare_env_names() {
        let token = ProviderCredentialStore.cloudflareEnvironmentToken(env: ["CF_WRITE_TOKEN": " write-token "])
        XCTAssertEqual(token, "write-token")
    }

    func test_pull_parses_secret_names() async throws {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockCFProtocol.self]
        MockCFProtocol.handler = { request in
            let body = """
            {"success":true,"result":[{"name":"CF_API_TOKEN","type":"secret_text"}]}
            """
            let resp = HTTPURLResponse(
                url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil
            )!
            return (resp, body.data(using: .utf8)!)
        }
        let session = URLSession(configuration: config)
        let provider = CloudflareProvider(session: session, tokenSource: { "tok" })
        let secrets = try await provider.pull(target: ProviderTarget(
            provider: "cloudflare",
            scope: ["account_id": "acc", "script_name": "worker"]
        ))
        XCTAssertEqual(secrets.map(\.name), ["CF_API_TOKEN"])
        XCTAssertEqual(secrets.first?.value, "")
    }

    func test_push_percent_encodes_scope_and_sends_secret_body() async throws {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockCFProtocol.self]
        MockCFProtocol.handler = { request in
            let body = #"{"success":true,"result":{}}"#
            let resp = HTTPURLResponse(
                url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil
            )!
            return (resp, Data(body.utf8))
        }
        let session = URLSession(configuration: config)
        let provider = CloudflareProvider(session: session, tokenSource: { "tok" })

        let result = try await provider.push(
            secrets: [Secret(name: "API_TOKEN", value: "secret-value")],
            target: ProviderTarget(
                provider: "cloudflare",
                scope: ["account_id": "acc id", "script_name": "my worker"]
            )
        )

        XCTAssertEqual(result.pushed, ["API_TOKEN"])
        let request = try XCTUnwrap(MockCFProtocol.requests.first)
        XCTAssertTrue(request.url?.absoluteString.contains("/client/v4/accounts/acc%20id/workers/scripts/my%20worker/secrets") == true)
        XCTAssertEqual(request.httpMethod, "PUT")
        let data = try XCTUnwrap(MockCFProtocol.bodies.first)
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        XCTAssertEqual(json["name"] as? String, "API_TOKEN")
        XCTAssertEqual(json["text"] as? String, "secret-value")
        XCTAssertEqual(json["type"] as? String, "secret_text")
    }

    func test_push_treats_cloudflare_success_false_as_failure() async throws {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockCFProtocol.self]
        MockCFProtocol.handler = { request in
            let body = #"{"success":false,"errors":[{"message":"script not found"}]}"#
            let resp = HTTPURLResponse(
                url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil
            )!
            return (resp, Data(body.utf8))
        }
        let session = URLSession(configuration: config)
        let provider = CloudflareProvider(session: session, tokenSource: { "tok" })

        let result = try await provider.push(
            secrets: [Secret(name: "API_TOKEN", value: "secret-value")],
            target: ProviderTarget(
                provider: "cloudflare",
                scope: ["account_id": "acc", "script_name": "worker"]
            )
        )

        XCTAssertEqual(result.pushed, [])
        XCTAssertEqual(result.failed.first?.name, "API_TOKEN")
        XCTAssertEqual(result.failed.first?.reason, "script not found")
    }
}

private final class MockCFProtocol: URLProtocol {
    static var handler: ((URLRequest) -> (HTTPURLResponse, Data))?
    static var requests: [URLRequest] = []
    static var bodies: [Data] = []

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        guard let handler = Self.handler else { return }
        Self.requests.append(request)
        if let body = Self.bodyData(from: request) {
            Self.bodies.append(body)
        }
        let (resp, data) = handler(request)
        client?.urlProtocol(self, didReceive: resp, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: data)
        client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() {}

    private static func bodyData(from request: URLRequest) -> Data? {
        if let body = request.httpBody {
            return body
        }

        guard let stream = request.httpBodyStream else { return nil }
        stream.open()
        defer { stream.close() }

        var data = Data()
        var buffer = [UInt8](repeating: 0, count: 4096)
        while true {
            let count = stream.read(&buffer, maxLength: buffer.count)
            if count > 0 {
                data.append(buffer, count: count)
            } else {
                break
            }
        }
        return data.isEmpty ? nil : data
    }
}
