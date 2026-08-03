import Foundation
import VaultCore

extension AppEnvironment {
    var pushciProjectPath: String {
        if !settings.pushciProjectPath.isEmpty { return settings.pushciProjectPath }
        return lastScannedURL?.path ?? ""
    }

    var pushciProjectId: String { settings.pushciProjectId }

    /// Cloud mode when a PushCI project UUID is set; otherwise local CLI path.
    var pushciUsesCloud: Bool {
        !pushciProjectId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var pushciScopeComplete: Bool {
        if pushciUsesCloud { return PushciConfig.cloudToken(prefs: prefs) != nil }
        return FileManager.default.fileExists(atPath: pushciProjectPath)
    }

    var hasPushciCLI: Bool {
        PushciConfig.cloudToken(prefs: prefs) != nil || pushciScopeComplete
    }

    func setPushciProjectPath(_ path: String) {
        settings.pushciProjectPath = path
        persistSettings()
    }

    func setPushciProjectId(_ id: String) {
        settings.pushciProjectId = id.trimmingCharacters(in: .whitespacesAndNewlines)
        persistSettings()
    }

    func setPushciAllowCI(_ on: Bool) {
        settings.pushciAllowCI = on
        persistSettings()
    }

    func pushciProvider() -> PushciProvider? {
        registry.provider(id: "pushci") as? PushciProvider
    }

    func pushciTarget() -> ProviderTarget {
        var scope: [String: String] = [:]
        if pushciUsesCloud {
            scope["project_id"] = pushciProjectId
            scope["environment"] = "*"
            if settings.pushciAllowCI { scope["allow_ci"] = "true" }
        } else {
            scope["project_path"] = pushciProjectPath
        }
        return ProviderTarget(provider: "pushci", scope: scope)
    }

    @MainActor
    func reconcilePushci() async throws -> ProviderNameReconcile {
        guard let provider = pushciProvider() else { throw ProviderError.unsupported("pushci") }
        return try await ProviderNameSync.reconcile(
            provider: provider,
            target: pushciTarget(),
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
        let result = try await provider.push(secrets: items, target: pushciTarget())
        for name in result.pushed {
            try service.recordEvent(name: name, action: .push, projectPath: pushciProjectPath)
        }
        return result
    }
}
