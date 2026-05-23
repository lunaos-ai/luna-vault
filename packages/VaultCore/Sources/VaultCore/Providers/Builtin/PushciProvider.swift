import Foundation

/// Stub provider for pushci.dev — user-owned product, API spec pending.
/// Skeleton lets us register the provider and wire the UI; real endpoints land once docs ship.
public final class PushciProvider: SecretProvider, @unchecked Sendable {
    public let id = "pushci"
    public let displayName = "pushci.dev"
    public let requiredScopeKeys = ["workspace"]

    private let session: URLSession
    private let tokenSource: () -> String?
    private let baseURL: URL

    public init(
        session: URLSession = .shared,
        baseURL: URL = URL(string: "https://api.pushci.dev")!,
        tokenSource: @escaping () -> String? = { ProcessInfo.processInfo.environment["PUSHCI_TOKEN"] }
    ) {
        self.session = session
        self.baseURL = baseURL
        self.tokenSource = tokenSource
    }

    public func authToken() throws -> String {
        guard let t = tokenSource(), !t.isEmpty else { throw ProviderError.missingAuth(id) }
        return t
    }

    public func push(secrets: [Secret], target: ProviderTarget) async throws -> ProviderPushResult {
        throw ProviderError.unsupported("pushci adapter pending API spec; track in v0.1 roadmap")
    }

    public func pull(target: ProviderTarget) async throws -> [Secret] {
        throw ProviderError.unsupported("pushci adapter pending API spec; track in v0.1 roadmap")
    }
}
