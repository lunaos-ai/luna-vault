import Foundation
import VaultCore

extension AppEnvironment {
    var cloudflareScope: [String: String] {
        var scope: [String: String] = [:]
        if !settings.cloudflareAccountId.isEmpty { scope["account_id"] = settings.cloudflareAccountId }
        if !settings.cloudflareScriptName.isEmpty { scope["script_name"] = settings.cloudflareScriptName }
        return scope
    }

    var cloudflareScopeComplete: Bool {
        !settings.cloudflareAccountId.isEmpty && !settings.cloudflareScriptName.isEmpty
    }

    var hasCloudflareToken: Bool {
        ProviderCredentialStore.cloudflareToken(prefs: prefs) != nil
            || ProcessInfo.processInfo.environment["CLOUDFLARE_API_TOKEN"]?.isEmpty == false
    }

    func updateCloudflareScope(from projectURL: URL) {
        let cfg = WranglerConfig.load(from: projectURL)
        if let id = cfg.accountId { settings.cloudflareAccountId = id }
        if let name = cfg.scriptName { settings.cloudflareScriptName = name }
        persistSettings()
    }

    func setCloudflareScope(accountId: String, scriptName: String) {
        settings.cloudflareAccountId = accountId
        settings.cloudflareScriptName = scriptName
        persistSettings()
    }

    func setCloudflareToken(_ token: String) {
        ProviderCredentialStore.setCloudflareToken(token.nilIfEmpty, prefs: prefs)
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
        let target = ProviderTarget(provider: "cloudflare", scope: cloudflareScope)
        return try await CloudflareSync.reconcile(
            provider: provider,
            target: target,
            localNames: cloudflareWorkerNames(inVault: projectURL)
        )
    }

    @MainActor
    func pushToCloudflare(vaultNames: Set<String>) async throws -> ProviderPushResult {
        guard let provider = cloudflareProvider() else { throw ProviderError.unsupported("cloudflare") }
        let prefix = lastScannedURL.map { SecretNaming.defaultProjectPrefix(from: $0) } ?? ""
        var items: [Secret] = []
        for vaultName in vaultNames {
            let secret = try await service.read(
                name: vaultName, reason: "Push \(vaultName) to Cloudflare Workers"
            )
            let workerName = workerName(forVaultName: vaultName, prefix: prefix)
            items.append(Secret(name: workerName, value: secret.value))
        }
        let target = ProviderTarget(provider: "cloudflare", scope: cloudflareScope)
        let result = try await provider.push(secrets: items, target: target)
        for vaultName in vaultNames {
            let worker = workerName(forVaultName: vaultName, prefix: prefix)
            if result.pushed.contains(worker) {
                try service.recordEvent(name: vaultName, action: .push, projectPath: lastScannedURL?.path)
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
}

private extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}
