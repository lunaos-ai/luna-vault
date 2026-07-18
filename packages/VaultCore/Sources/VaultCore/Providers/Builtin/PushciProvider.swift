import Foundation

/// Syncs vault secrets to PushCI's local encrypted store via `pushci secret` CLI.
/// Cloud REST API lands in pushci v0.2; this bridge matches how PushCI stores secrets today.
public final class PushciProvider: SecretProvider, @unchecked Sendable {
    public let id = "pushci"
    public let displayName = "pushci.dev"
    public let requiredScopeKeys = ["project_path"]

    private let tokenSource: () -> String?
    private let runner: PushciCLI.Runner

    public init(
        tokenSource: @escaping () -> String? = { ProcessInfo.processInfo.environment["PUSHCI_TOKEN"] },
        runner: @escaping PushciCLI.Runner = PushciCLI.defaultRunner
    ) {
        self.tokenSource = tokenSource
        self.runner = runner
    }

    public func authToken() throws -> String {
        if let t = tokenSource(), !t.isEmpty { return t }
        return "local"
    }

    public func push(secrets: [Secret], target: ProviderTarget) async throws -> ProviderPushResult {
        let root = try projectURL(from: target)
        var pushed: [String] = []
        var failed: [(String, String)] = []
        for secret in secrets {
            do {
                try PushciCLI.setValue(name: secret.name, value: secret.value, projectPath: root, runner: runner)
                pushed.append(secret.name)
            } catch {
                failed.append((secret.name, "\(error)"))
            }
        }
        return ProviderPushResult(pushed: pushed, skipped: [], failed: failed)
    }

    public func pull(target: ProviderTarget) async throws -> [Secret] {
        let root = try projectURL(from: target)
        let keys = try PushciCLI.listKeys(projectPath: root, runner: runner)
        var items: [Secret] = []
        for key in keys {
            do {
                let value = try PushciCLI.getValue(name: key, projectPath: root, runner: runner)
                items.append(Secret(name: key, value: value))
            } catch {
                items.append(Secret(name: key, value: ""))
            }
        }
        return items
    }

    private func projectURL(from target: ProviderTarget) throws -> URL {
        guard let path = target.scope["project_path"], !path.isEmpty else {
            throw PushciCLIError.missingProjectPath
        }
        return URL(fileURLWithPath: path, isDirectory: true)
    }
}
