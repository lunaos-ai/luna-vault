import XCTest
@testable import VaultCore

/// Records calls and returns scripted results — no real subprocess spawned.
final class StubRunner: ProcessRunner, @unchecked Sendable {
    struct Call { let executable: String; let args: [String]; let stdin: Data? }
    private(set) var calls: [Call] = []
    var results: [ProcessResult]
    private var index = 0

    init(results: [ProcessResult]) { self.results = results }

    func run(executable: String, args: [String], stdin: Data?) throws -> ProcessResult {
        calls.append(Call(executable: executable, args: args, stdin: stdin))
        defer { index += 1 }
        return results[min(index, results.count - 1)]
    }
}

final class WranglerCloudflareProviderTests: XCTestCase {
    private func ok(_ out: String = "logged in") -> ProcessResult {
        ProcessResult(exitCode: 0, stdout: out, stderr: "")
    }

    func testPushPipesSecretsOverStdinNotArgv() async throws {
        let runner = StubRunner(results: [ok(), ok()]) // whoami, bulk
        let provider = WranglerCloudflareProvider(runner: runner)
        let secrets = [Secret(name: "API_KEY", value: "supersecret")]

        let result = try await provider.push(
            secrets: secrets,
            target: ProviderTarget(provider: "cloudflare-wrangler", scope: ["worker": "api"])
        )

        XCTAssertEqual(result.pushed, ["API_KEY"])
        XCTAssertTrue(result.failed.isEmpty)

        let bulk = runner.calls.last!
        XCTAssertEqual(bulk.args, ["secret", "bulk", "--name", "api"])
        // Security: secret value must never leak into argv.
        XCTAssertFalse(bulk.args.contains { $0.contains("supersecret") })
        let body = String(data: bulk.stdin ?? Data(), encoding: .utf8) ?? ""
        XCTAssertTrue(body.contains("supersecret"))
        XCTAssertTrue(body.contains("API_KEY"))
    }

    func testPushFailsAllWhenWranglerExitsNonZero() async throws {
        let runner = StubRunner(results: [
            ok(),
            ProcessResult(exitCode: 1, stdout: "", stderr: "worker not found")
        ])
        let provider = WranglerCloudflareProvider(runner: runner)

        let result = try await provider.push(
            secrets: [Secret(name: "A", value: "1")],
            target: ProviderTarget(provider: "cloudflare-wrangler", scope: ["worker": "ghost"])
        )

        XCTAssertTrue(result.pushed.isEmpty)
        XCTAssertEqual(result.failed.first?.name, "A")
        XCTAssertEqual(result.failed.first?.reason, "worker not found")
    }

    func testMissingAuthThrowsWhenNotLoggedIn() async {
        let runner = StubRunner(results: [ProcessResult(exitCode: 1, stdout: "", stderr: "")])
        let provider = WranglerCloudflareProvider(runner: runner)
        await XCTAssertThrowsErrorAsync(
            try await provider.push(
                secrets: [Secret(name: "A", value: "1")],
                target: ProviderTarget(provider: "cloudflare-wrangler", scope: ["worker": "api"])
            )
        )
    }

    func testMissingWorkerScopeThrows() async {
        let runner = StubRunner(results: [ok()])
        let provider = WranglerCloudflareProvider(runner: runner)
        await XCTAssertThrowsErrorAsync(
            try await provider.push(
                secrets: [Secret(name: "A", value: "1")],
                target: ProviderTarget(provider: "cloudflare-wrangler", scope: [:])
            )
        )
    }

    func testPullParsesSecretNames() async throws {
        let json = #"[{"name":"API_KEY","type":"secret_text"},{"name":"DB_URL","type":"secret_text"}]"#
        let runner = StubRunner(results: [ok(json)])
        let provider = WranglerCloudflareProvider(runner: runner)

        let secrets = try await provider.pull(
            target: ProviderTarget(provider: "cloudflare-wrangler", scope: ["worker": "api"])
        )

        XCTAssertEqual(secrets.map(\.name), ["API_KEY", "DB_URL"])
        XCTAssertTrue(secrets.allSatisfy { $0.value.isEmpty })
    }

    func testParseSecretListIgnoresLeadingLogNoise() {
        let provider = WranglerCloudflareProvider(runner: StubRunner(results: [ok()]))
        let out = "⛅️ wrangler 4.73\n[{\"name\":\"X\",\"type\":\"secret_text\"}]"
        XCTAssertEqual(provider.parseSecretList(out), ["X"])
    }
}

func XCTAssertThrowsErrorAsync(
    _ expression: @autoclosure () async throws -> some Any,
    file: StaticString = #filePath,
    line: UInt = #line
) async {
    do {
        _ = try await expression()
        XCTFail("Expected error but none thrown", file: file, line: line)
    } catch {}
}
