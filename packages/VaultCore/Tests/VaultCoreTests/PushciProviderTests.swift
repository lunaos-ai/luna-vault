import XCTest
@testable import VaultCore

final class PushciProviderTests: XCTestCase {
    private var calls: [(URL, [String])] = []

    override func setUp() {
        super.setUp()
        calls = []
    }

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

    func test_cloud_token_from_cli_config() throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("vv-pushci-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let cfgDir = dir.appendingPathComponent(".pushci", isDirectory: true)
        try FileManager.default.createDirectory(at: cfgDir, withIntermediateDirectories: true)
        let cfg = #"{"token":" jwt-from-file ","email":"dev@example.com"}"#
        try Data(cfg.utf8).write(to: cfgDir.appendingPathComponent("config.json"))
        XCTAssertEqual(PushciConfig.loadCLIConfigToken(home: dir), "jwt-from-file")
    }

    func test_cloud_token_prefers_env() {
        let token = PushciConfig.cloudToken(
            prefs: InMemoryPrefs(),
            env: ["PUSHCI_TOKEN": " env-tok "],
            home: URL(fileURLWithPath: "/nonexistent-\(UUID().uuidString)")
        )
        XCTAssertEqual(token, "env-tok")
    }
}
