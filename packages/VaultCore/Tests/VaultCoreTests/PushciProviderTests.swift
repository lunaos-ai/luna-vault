import XCTest
@testable import VaultCore

final class PushciProviderTests: XCTestCase {
    private var calls: [(URL, [String], String?)] = []

    private func mockRunner(projectPath: URL, args: [String], input: String?) throws -> String {
        calls.append((projectPath, args, input))
        switch args {
        case ["secret", "list"]:
            return "  • API_TOKEN\n  • DATABASE_URL\n"
        case ["secret", "get", "API_TOKEN"]:
            return "tok123\n"
        case ["secret", "get", "DATABASE_URL"]:
            return "postgres://local\n"
        case ["secret", "set", "NEW_KEY", "--from-stdin"]:
            return "Set secret: NEW_KEY\n"
        default:
            throw PushciCLIError.commandFailed(PushciCLI.describe(args), "unexpected")
        }
    }

    func test_parseListOutput() {
        let keys = PushciCLI.parseListOutput("  • FOO\n  • BAR\nNo secrets stored\n")
        XCTAssertEqual(keys, ["FOO", "BAR"])
    }

    func test_pull_reads_values() async throws {
        let provider = PushciProvider(runner: mockRunner)
        let target = ProviderTarget(provider: "pushci", scope: ["project_path": "/tmp/my-app"])
        let secrets = try await provider.pull(target: target)
        XCTAssertEqual(secrets.map(\.name).sorted(), ["API_TOKEN", "DATABASE_URL"])
        XCTAssertEqual(secrets.first { $0.name == "API_TOKEN" }?.value, "tok123")
    }

    func test_push_invokes_set() async throws {
        let provider = PushciProvider(runner: mockRunner)
        let target = ProviderTarget(provider: "pushci", scope: ["project_path": "/tmp/my-app"])
        let result = try await provider.push(
            secrets: [Secret(name: "NEW_KEY", value: "new-val")],
            target: target
        )
        XCTAssertEqual(result.pushed, ["NEW_KEY"])
        XCTAssertTrue(calls.contains { $0.1 == ["secret", "set", "NEW_KEY", "--from-stdin"] })
    }

    /// A secret in argv is readable by any local process via `ps`, and pushci
    /// records argv in its audit receipts. The value must only ever travel on
    /// stdin.
    func test_push_never_puts_the_value_in_argv() async throws {
        let provider = PushciProvider(runner: mockRunner)
        let target = ProviderTarget(provider: "pushci", scope: ["project_path": "/tmp/my-app"])
        _ = try await provider.push(
            secrets: [Secret(name: "NEW_KEY", value: "new-val")],
            target: target
        )
        for (_, args, _) in calls {
            XCTAssertFalse(args.contains("new-val"), "secret leaked into argv: \(args)")
        }
        XCTAssertEqual(calls.last?.2, "new-val", "value must be piped to stdin")
    }

    /// pushci rejects a positional value, so the old call always failed — and
    /// the failure echoed the value back. Error text must stay clean whatever
    /// the arguments were.
    func test_failure_message_redacts_positional_values() {
        let described = PushciCLI.describe(["secret", "set", "MY_KEY", "s3cr3t-value"])
        XCTAssertFalse(described.contains("s3cr3t-value"))
        XCTAssertTrue(described.contains("MY_KEY"))
        XCTAssertEqual(described, "secret set MY_KEY <redacted>")

        let error = PushciCLIError.commandFailed(described, "secret value must be supplied with --from-stdin")
        XCTAssertFalse("\(error)".contains("s3cr3t-value"))
    }

    func test_describe_keeps_flags_and_short_commands_readable() {
        XCTAssertEqual(PushciCLI.describe(["secret", "set", "K", "--from-stdin"]), "secret set K --from-stdin")
        XCTAssertEqual(PushciCLI.describe(["secret", "list"]), "secret list")
        XCTAssertEqual(PushciCLI.describe(["secret", "get", "K"]), "secret get K")
    }

    /// The provider records the error string per secret; that string is
    /// surfaced in the CLI, the app, and MCP tool output.
    func test_push_failure_result_carries_no_secret_value() async throws {
        let provider = PushciProvider(runner: mockRunner)
        let target = ProviderTarget(provider: "pushci", scope: ["project_path": "/tmp/my-app"])
        let result = try await provider.push(
            secrets: [Secret(name: "UNKNOWN_KEY", value: "top-secret")],
            target: target
        )
        XCTAssertEqual(result.failed.map(\.0), ["UNKNOWN_KEY"])
        for (_, message) in result.failed {
            XCTAssertFalse(message.contains("top-secret"), "secret leaked into failure: \(message)")
        }
    }

    func test_missing_project_path() async {
        let provider = PushciProvider(runner: mockRunner)
        let target = ProviderTarget(provider: "pushci", scope: [:])
        do {
            _ = try await provider.pull(target: target)
            XCTFail("expected error")
        } catch {
            XCTAssertTrue("\(error)".contains("project_path"))
        }
    }
}
