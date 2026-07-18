import AppKit
import Foundation
import VaultCore

extension AppEnvironment {
    var vercelScope: [String: String] {
        var scope: [String: String] = [:]
        if !settings.vercelProjectId.isEmpty { scope["project_id"] = settings.vercelProjectId }
        if !settings.vercelTeamId.isEmpty { scope["team_id"] = settings.vercelTeamId }
        return scope
    }

    var vercelScopeComplete: Bool { !settings.vercelProjectId.isEmpty }

    func setVercelScope(projectId: String, teamId: String) {
        settings.vercelProjectId = projectId
        settings.vercelTeamId = teamId
        persistSettings()
    }

    func setVercelToken(_ token: String) {
        ProviderCredentialStore.setVercelToken(token.isEmpty ? nil : token, prefs: prefs)
        cachedHasVercelToken =
            !token.isEmpty
            || ProcessInfo.processInfo.environment["VERCEL_TOKEN"]?.isEmpty == false
    }

    func vercelProvider() -> VercelProvider? {
        registry.provider(id: "vercel") as? VercelProvider
    }

    @MainActor
    func reconcileVercel() async throws -> ProviderNameReconcile {
        guard let provider = vercelProvider() else { throw ProviderError.unsupported("vercel") }
        let target = ProviderTarget(provider: "vercel", scope: vercelScope)
        return try await ProviderNameSync.reconcile(
            provider: provider,
            target: target,
            localNames: Set(secrets.map(\.name))
        )
    }

    @MainActor
    func pushToVercel(names: Set<String>) async throws -> ProviderPushResult {
        guard let provider = vercelProvider() else { throw ProviderError.unsupported("vercel") }
        var items: [Secret] = []
        for name in names {
            let secret = try await service.read(name: name, reason: "Push \(name) to Vercel")
            items.append(Secret(name: name, value: secret.value))
        }
        let target = ProviderTarget(provider: "vercel", scope: vercelScope)
        let result = try await provider.push(secrets: items, target: target)
        for name in result.pushed {
            try service.recordEvent(name: name, action: .push, projectPath: lastScannedURL?.path)
        }
        return result
    }

    @MainActor
    @discardableResult
    func copySecret(name: String) async -> Bool {
        do {
            let fresh = try await service.read(name: name, reason: "Copy \(name)")
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(fresh.value, forType: .string)
            showToast("Copied \(name)")
            return true
        } catch {
            lastError = "\(error)"
            showToast("Copy failed", feedback: .caution)
            return false
        }
    }
}
