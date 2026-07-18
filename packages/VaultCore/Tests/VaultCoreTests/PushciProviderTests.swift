import XCTest
@testable import VaultCore

final class PushciProviderTests: XCTestCase {
    private var calls: [(URL, [String])] = []

    private func mockRunner(projectPath: URL, args: [String]) throws -> String {
        calls.append((projectPath, args))
        switch args {
        case ["secret", "list"]:
            return "  • API_TOKEN\n  • DATABASE_URL\n"
        case ["secret", "get", "API_TOKEN"]:
            return "tok123\n"
        case ["secret", "get", "DATABASE_URL"]:
            return "postgres://local\n"
        case ["secret", "set", "NEW_KEY", "new-val"]:
            return "Set secret: NEW_KEY\n"
        default:
            throw PushciCLIError.commandFailed(args.joined(separator: " "), "unexpected")
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
        XCTAssertTrue(calls.contains { $0.1 == ["secret", "set", "NEW_KEY", "new-val"] })
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
