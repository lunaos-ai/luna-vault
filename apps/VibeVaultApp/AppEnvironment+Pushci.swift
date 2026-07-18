import Foundation
import VaultCore

extension AppEnvironment {
    var pushciProjectPath: String {
        if !settings.pushciProjectPath.isEmpty { return settings.pushciProjectPath }
        return lastScannedURL?.path ?? ""
    }

    var pushciScopeComplete: Bool {
        FileManager.default.fileExists(atPath: pushciProjectPath)
    }

    var hasPushciCLI: Bool {
        ProcessInfo.processInfo.environment["PUSHCI_TOKEN"]?.isEmpty == false
            || pushciScopeComplete
    }

    func setPushciProjectPath(_ path: String) {
        settings.pushciProjectPath = path
        persistSettings()
    }

    func pushciProvider() -> PushciProvider? {
        registry.provider(id: "pushci") as? PushciProvider
    }

    @MainActor
    func reconcilePushci() async throws -> ProviderNameReconcile {
        guard let provider = pushciProvider() else { throw ProviderError.unsupported("pushci") }
        let target = ProviderTarget(provider: "pushci", scope: ["project_path": pushciProjectPath])
        return try await ProviderNameSync.reconcile(
            provider: provider,
            target: target,
            localNames: Set(secrets.map(\.name))
        )
    }

    @MainActor
    func pushToPushci(names: Set<String>) async throws -> ProviderPushResult {
        guard let provider = pushciProvider() else { throw ProviderError.unsupported("pushci") }
        var items: [Secret] = []
        for name in names {
            let secret = try await service.read(name: name, reason: "Push \(name) to PushCI")
            items.append(Secret(name: name, value: secret.value))
        }
        let target = ProviderTarget(provider: "pushci", scope: ["project_path": pushciProjectPath])
        let result = try await provider.push(secrets: items, target: target)
        for name in result.pushed {
            try service.recordEvent(name: name, action: .push, projectPath: pushciProjectPath)
        }
        return result
    }
}
