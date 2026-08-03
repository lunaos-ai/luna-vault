import XCTest
@testable import VaultCore

final class PushciCloudAPITests: XCTestCase {
    override func setUp() {
        super.setUp()
        MockPushciProtocol.handler = nil
        MockPushciProtocol.requests = []
        MockPushciProtocol.bodies = []
    }

    private func mockSession() -> URLSession {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockPushciProtocol.self]
        return URLSession(configuration: config)
    }

    private func provider(cloud: PushciCloudAPI) -> PushciProvider {
        PushciProvider(tokenSource: { "jwt" }, runner: { _, _ in "" }, cloud: cloud)
    }

    func test_cloud_pull_lists_names_only() async throws {
        MockPushciProtocol.handler = { request in
            XCTAssertEqual(request.httpMethod, "GET")
            XCTAssertTrue(request.url?.absoluteString.contains("/api/projects/proj-1/secrets") == true)
            let body = #"{"secrets":[{"name":"FOO","environment":"*"},{"name":"BAR","environment":"staging"}]}"#
            let resp = HTTPURLResponse(
                url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil
            )!
            return (resp, Data(body.utf8))
        }
        let cloud = PushciCloudAPI(apiBase: "https://api.pushci.dev", session: mockSession())
        let secrets = try await provider(cloud: cloud).pull(
            target: ProviderTarget(provider: "pushci", scope: ["project_id": "proj-1"])
        )
        XCTAssertEqual(Set(secrets.map(\.name)), ["FOO", "BAR"])
        XCTAssertTrue(secrets.allSatisfy { $0.value.isEmpty })
    }

    func test_cloud_push_puts_secret_body() async throws {
        MockPushciProtocol.handler = { request in
            XCTAssertEqual(request.httpMethod, "PUT")
            XCTAssertTrue(
                request.url?.absoluteString.contains("/api/projects/proj-1/secrets/DATABASE_URL") == true
            )
            let resp = HTTPURLResponse(
                url: request.url!, statusCode: 201, httpVersion: nil, headerFields: nil
            )!
            return (resp, Data(#"{"secret":{"name":"DATABASE_URL"}}"#.utf8))
        }
        let cloud = PushciCloudAPI(apiBase: "https://api.pushci.dev", session: mockSession())
        let result = try await provider(cloud: cloud).push(
            secrets: [Secret(name: "DATABASE_URL", value: "postgres://x")],
            target: ProviderTarget(
                provider: "pushci",
                scope: ["project_id": "proj-1", "environment": "*"]
            )
        )
        XCTAssertEqual(result.pushed, ["DATABASE_URL"])
        XCTAssertTrue(result.failed.isEmpty)
        let body = try XCTUnwrap(MockPushciProtocol.bodies.first)
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: Any])
        XCTAssertEqual(json["environment"] as? String, "*")
        XCTAssertEqual(json["value"] as? String, "postgres://x")
    }

    func test_cloud_push_allow_ci_updates_policy() async throws {
        MockPushciProtocol.handler = { request in
            let path = request.url?.path ?? ""
            if path.hasSuffix("/secrets/FOO"), request.httpMethod == "PUT" {
                let resp = HTTPURLResponse(
                    url: request.url!, statusCode: 201, httpVersion: nil, headerFields: nil
                )!
                return (resp, Data(#"{"secret":{"name":"FOO"}}"#.utf8))
            }
            if path.hasSuffix("/execution"), request.httpMethod == "GET" {
                let body = #"{"policy":{"project_id":"proj-1","ci":{"prefer":"managed","allow":["managed"],"fallback":false,"capabilities":[]},"deploy":{"prefer":"managed","allow":["managed"],"fallback":false,"capabilities":[]},"secret_names":["FOO"],"ci_secret_names":[],"region":"global"}}"#
                let resp = HTTPURLResponse(
                    url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil
                )!
                return (resp, Data(body.utf8))
            }
            if path.hasSuffix("/execution"), request.httpMethod == "PUT" {
                let resp = HTTPURLResponse(
                    url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil
                )!
                return (resp, Data(#"{"policy":{}}"#.utf8))
            }
            XCTFail("unexpected \(request.httpMethod ?? "?") \(path)")
            let resp = HTTPURLResponse(
                url: request.url!, statusCode: 500, httpVersion: nil, headerFields: nil
            )!
            return (resp, Data())
        }
        let cloud = PushciCloudAPI(apiBase: "https://api.pushci.dev", session: mockSession())
        let result = try await provider(cloud: cloud).push(
            secrets: [Secret(name: "FOO", value: "bar")],
            target: ProviderTarget(
                provider: "pushci",
                scope: ["project_id": "proj-1", "allow_ci": "true"]
            )
        )
        XCTAssertEqual(result.pushed, ["FOO"])
        XCTAssertTrue(result.failed.isEmpty)
        XCTAssertEqual(MockPushciProtocol.requests.count, 3)
        let putPolicy = try XCTUnwrap(MockPushciProtocol.bodies.last)
        let policy = try XCTUnwrap(JSONSerialization.jsonObject(with: putPolicy) as? [String: Any])
        XCTAssertEqual(policy["ci_secret_names"] as? [String], ["FOO"])
    }

    func test_cloud_missing_auth() async {
        let provider = PushciProvider(tokenSource: { nil }, runner: { _, _ in "" })
        do {
            _ = try await provider.push(
                secrets: [Secret(name: "FOO", value: "x")],
                target: ProviderTarget(provider: "pushci", scope: ["project_id": "proj-1"])
            )
            XCTFail("expected auth error")
        } catch {
            XCTAssertTrue("\(error)".localizedCaseInsensitiveContains("auth"))
        }
    }
}

final class MockPushciProtocol: URLProtocol {
    static var handler: ((URLRequest) -> (HTTPURLResponse, Data))?
    static var requests: [URLRequest] = []
    static var bodies: [Data] = []

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        guard let handler = Self.handler else { return }
        Self.requests.append(request)
        if let body = Self.bodyData(from: request) { Self.bodies.append(body) }
        let (resp, data) = handler(request)
        client?.urlProtocol(self, didReceive: resp, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: data)
        client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() {}

    private static func bodyData(from request: URLRequest) -> Data? {
        if let body = request.httpBody { return body }
        guard let stream = request.httpBodyStream else { return nil }
        stream.open()
        defer { stream.close() }
        var data = Data()
        var buffer = [UInt8](repeating: 0, count: 4096)
        while true {
            let count = stream.read(&buffer, maxLength: buffer.count)
            if count > 0 { data.append(buffer, count: count) } else { break }
        }
        return data.isEmpty ? nil : data
    }
}
