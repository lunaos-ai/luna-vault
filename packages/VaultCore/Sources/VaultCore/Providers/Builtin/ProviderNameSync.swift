import Foundation

/// Name-only reconcile between vault and a remote provider (values never compared).
public struct ProviderNameReconcile: Equatable, Sendable {
    public let remoteNames: Set<String>
    public let localNames: Set<String>
    public let missingLocally: Set<String>
    public let extraLocally: Set<String>
    public let inSync: Set<String>

    public init(remoteNames: Set<String>, localNames: Set<String>) {
        self.remoteNames = remoteNames
        self.localNames = localNames
        missingLocally = remoteNames.subtracting(localNames)
        extraLocally = localNames.subtracting(remoteNames)
        inSync = remoteNames.intersection(localNames)
    }
}

public typealias CloudflareReconcile = ProviderNameReconcile

public enum ProviderNameSync {
    public static func reconcile(
        provider: SecretProvider,
        target: ProviderTarget,
        localNames: Set<String>
    ) async throws -> ProviderNameReconcile {
        let remote = try await provider.pull(target: target)
        return ProviderNameReconcile(
            remoteNames: Set(remote.map(\.name)),
            localNames: localNames
        )
    }
}

public enum CloudflareSync {
    public static func reconcile(
        provider: SecretProvider,
        target: ProviderTarget,
        localNames: Set<String>
    ) async throws -> CloudflareReconcile {
        try await ProviderNameSync.reconcile(
            provider: provider, target: target, localNames: localNames
        )
    }
}
