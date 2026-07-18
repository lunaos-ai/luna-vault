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
}

final class CloudflareProviderTests: XCTestCase {
    func test_missing_token_throws() {
        let provider = CloudflareProvider(tokenSource: { nil })
        XCTAssertThrowsError(try provider.authToken())
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
}

private final class MockCFProtocol: URLProtocol {
    static var handler: ((URLRequest) -> (HTTPURLResponse, Data))?

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        guard let handler = Self.handler else { return }
        let (resp, data) = handler(request)
        client?.urlProtocol(self, didReceive: resp, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: data)
        client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() {}
}
