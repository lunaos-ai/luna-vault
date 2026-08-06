import Foundation

/// Syncs vault secrets to PushCI — local CLI store or cloud project secrets API.
///
/// Scope modes:
/// - `project_id` (+ optional `environment`, `allow_ci`) → HTTPS `api.pushci.dev`
/// - `project_path` → local `pushci secret` CLI (`.pushci/secrets.enc`)
public final class PushciProvider: SecretProvider, @unchecked Sendable {
    public let id = "pushci"
    public let displayName = "pushci.dev"
    public let requiredScopeKeys = ["project_id"] // or project_path for local CLI

    private let tokenSource: () -> String?
    private let runner: PushciCLI.Runner
    private let cloud: PushciCloudAPI

    public init(
        tokenSource: @escaping () -> String? = {
            PushciConfig.cloudToken()
        },
        runner: @escaping PushciCLI.Runner = PushciCLI.defaultRunner,
        cloud: PushciCloudAPI = PushciCloudAPI(apiBase: PushciConfig.apiBase())
    ) {
        self.tokenSource = tokenSource
        self.runner = runner
        self.cloud = cloud
    }

    public func authToken() throws -> String {
        if let t = tokenSource()?.trimmingCharacters(in: .whitespacesAndNewlines), !t.isEmpty {
            return t
        }
        return "local"
    }

    public func push(secrets: [Secret], target: ProviderTarget) async throws -> ProviderPushResult {
        if let projectId = clean(target.scope["project_id"]) {
            return try await pushCloud(secrets: secrets, projectId: projectId, scope: target.scope)
        }
        return try pushLocal(secrets: secrets, target: target)
    }

    public func pull(target: ProviderTarget) async throws -> [Secret] {
        if let projectId = clean(target.scope["project_id"]) {
            let token = try requireCloudToken()
            let names = try await cloud.listSecretNames(projectId: projectId, token: token)
            // Cloud list returns names only (values never leave the Worker).
            return names.map { Secret(name: $0, value: "") }
        }
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

    private func pushCloud(
        secrets: [Secret],
        projectId: String,
        scope: [String: String]
    ) async throws -> ProviderPushResult {
        let token = try requireCloudToken()
        let environment = clean(scope["environment"])?.lowercased() ?? "*"
        let allowCI = truthy(scope["allow_ci"])
        var pushed: [String] = []
        var failed: [(String, String)] = []
        for secret in secrets {
            do {
                try await cloud.putSecret(
                    projectId: projectId,
                    name: secret.name,
                    value: secret.value,
                    environment: environment,
                    token: token
                )
                pushed.append(secret.name)
            } catch {
                failed.append((secret.name, "\(error)"))
            }
        }
        if allowCI, !pushed.isEmpty {
            do {
                try await cloud.allowlistCISecrets(projectId: projectId, names: pushed, token: token)
            } catch {
                // Secret values already stored; surface allowlist failure separately.
                failed.append(("ci_secret_names", "\(error)"))
            }
        }
        return ProviderPushResult(pushed: pushed, skipped: [], failed: failed)
    }

    private func pushLocal(secrets: [Secret], target: ProviderTarget) throws -> ProviderPushResult {
        let root = try projectURL(from: target)
        var pushed: [String] = []
        var failed: [(String, String)] = []
        for secret in secrets {
            do {
                try PushciCLI.setValue(
                    name: secret.name, value: secret.value, projectPath: root, runner: runner
                )
                pushed.append(secret.name)
            } catch {
                failed.append((secret.name, "\(error)"))
            }
        }
        return ProviderPushResult(pushed: pushed, skipped: [], failed: failed)
    }

    private func requireCloudToken() throws -> String {
        let token = try authToken()
        guard token != "local" else { throw ProviderError.missingAuth(id) }
        return token
    }

    private func projectURL(from target: ProviderTarget) throws -> URL {
        guard let path = clean(target.scope["project_path"]) else {
            throw PushciCLIError.missingProjectPath
        }
        return URL(fileURLWithPath: path, isDirectory: true)
    }

    private func clean(_ value: String?) -> String? {
        let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed?.isEmpty == false ? trimmed : nil
    }

    private func truthy(_ value: String?) -> Bool {
        guard let v = clean(value)?.lowercased() else { return false }
        return ["1", "true", "yes", "on"].contains(v)
    }
}
