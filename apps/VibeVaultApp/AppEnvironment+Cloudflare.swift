import Foundation
import VaultCore

extension AppEnvironment {
    var cloudflareScope: [String: String] {
        cloudflareScope(projectURL: nil)
    }

    func cloudflareScope(projectURL: URL?) -> [String: String] {
        var scope: [String: String] = [:]
        if !settings.cloudflareAccountId.isEmpty { scope["account_id"] = settings.cloudflareAccountId }
        if !settings.cloudflareScriptName.isEmpty { scope["script_name"] = settings.cloudflareScriptName }
        if let projectURL {
            let cfg = WranglerConfig.load(from: projectURL)
            if scope["account_id"] == nil, let id = cfg.accountId { scope["account_id"] = id }
            if scope["script_name"] == nil, let name = cfg.scriptName { scope["script_name"] = name }
        }
        let env = ProcessInfo.processInfo.environment
        if scope["account_id"] == nil {
            scope["account_id"] = firstEnv(env, ["CLOUDFLARE_ACCOUNT_ID", "CF_ACCOUNT_ID"])
        }
        if scope["script_name"] == nil {
            scope["script_name"] = firstEnv(env, ["CLOUDFLARE_SCRIPT_NAME", "CF_SCRIPT_NAME", "WRANGLER_SCRIPT_NAME"])
        }
        return scope
    }

    var cloudflareScopeComplete: Bool {
        cloudflareScopeComplete(projectURL: nil)
    }

    func cloudflareScopeComplete(projectURL: URL?) -> Bool {
        let scope = cloudflareScope(projectURL: projectURL)
        return scope["account_id"]?.isEmpty == false && scope["script_name"]?.isEmpty == false
    }

    func updateCloudflareScope(from projectURL: URL) {
        let cfg = WranglerConfig.load(from: projectURL)
        var changed = false
        if let id = cfg.accountId, settings.cloudflareAccountId != id {
            settings.cloudflareAccountId = id
            changed = true
        }
        if let name = cfg.scriptName, settings.cloudflareScriptName != name {
            settings.cloudflareScriptName = name
            changed = true
        }
        if changed { persistSettings() }
    }

    func setCloudflareScope(accountId: String, scriptName: String) {
        settings.cloudflareAccountId = accountId
        settings.cloudflareScriptName = scriptName
        persistSettings()
    }

    func setCloudflareToken(_ token: String) {
        ProviderCredentialStore.setCloudflareToken(token.nilIfEmpty, prefs: prefs)
        cachedHasCloudflareToken =
            token.nilIfEmpty != nil
            || ProviderCredentialStore.cloudflareEnvironmentToken() != nil
    }

    func cloudflareProvider() -> CloudflareProvider? {
        registry.provider(id: "cloudflare") as? CloudflareProvider
    }

    func cloudflareWorkerNames(inVault projectURL: URL? = nil) -> Set<String> {
        let url = projectURL ?? lastScannedURL
        guard let url else { return Set(secrets.map(\.name)) }
        let prefix = SecretNaming.defaultProjectPrefix(from: url)
        return Set(secrets.map { workerName(forVaultName: $0.name, prefix: prefix) })
    }

    func vaultNames(matchingWorker names: Set<String>, projectURL: URL? = nil) -> Set<String> {
        let url = projectURL ?? lastScannedURL
        guard let url else { return names }
        let prefix = SecretNaming.defaultProjectPrefix(from: url)
        return Set(names.map { SecretNaming.applyPrefix(prefix, to: $0) })
    }

    @MainActor
    func reconcileCloudflare(projectURL: URL? = nil) async throws -> CloudflareReconcile {
        guard let provider = cloudflareProvider() else { throw ProviderError.unsupported("cloudflare") }
        let target = ProviderTarget(provider: "cloudflare", scope: cloudflareScope(projectURL: projectURL))
        return try await CloudflareSync.reconcile(
            provider: provider,
            target: target,
            localNames: cloudflareWorkerNames(inVault: projectURL)
        )
    }

    @MainActor
    func pushToCloudflare(vaultNames: Set<String>, projectURL: URL? = nil) async throws -> ProviderPushResult {
        guard let provider = cloudflareProvider() else { throw ProviderError.unsupported("cloudflare") }
        let url = projectURL ?? lastScannedURL
        let prefix = url.map { SecretNaming.defaultProjectPrefix(from: $0) } ?? ""
        var items: [Secret] = []
        for vaultName in vaultNames {
            let secret = try await service.read(
                name: vaultName, reason: "Push \(vaultName) to Cloudflare Workers"
            )
            let workerName = workerName(forVaultName: vaultName, prefix: prefix)
            items.append(Secret(name: workerName, value: secret.value))
        }
        let target = ProviderTarget(provider: "cloudflare", scope: cloudflareScope(projectURL: url))
        let result = try await provider.push(secrets: items, target: target)
        for vaultName in vaultNames {
            let worker = workerName(forVaultName: vaultName, prefix: prefix)
            if result.pushed.contains(worker) {
                try service.recordEvent(name: vaultName, action: .push, projectPath: url?.path)
            }
        }
        return result
    }

    private func workerName(forVaultName vaultName: String, prefix: String) -> String {
        if !prefix.isEmpty, vaultName.hasPrefix(prefix) {
            return String(vaultName.dropFirst(prefix.count))
        }
        return vaultName
    }

    private func firstEnv(_ env: [String: String], _ names: [String]) -> String? {
        for name in names {
            let value = env[name]?.trimmingCharacters(in: .whitespacesAndNewlines)
            if value?.isEmpty == false { return value }
        }
        return nil
    }
}

private extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}
