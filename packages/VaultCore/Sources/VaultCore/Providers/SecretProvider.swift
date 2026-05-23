import Foundation

public struct ProviderTarget: Equatable, Sendable {
    public let provider: String       // "cloudflare", "vercel", "pushci"
    public let scope: [String: String] // e.g. ["account": "...", "project": "..."]

    public init(provider: String, scope: [String: String]) {
        self.provider = provider
        self.scope = scope
    }
}

public struct ProviderPushResult: Equatable, Sendable {
    public let pushed: [String]
    public let skipped: [String]
    public let failed: [(name: String, reason: String)]

    public init(pushed: [String] = [], skipped: [String] = [], failed: [(name: String, reason: String)] = []) {
        self.pushed = pushed
        self.skipped = skipped
        self.failed = failed
    }

    public static func == (lhs: ProviderPushResult, rhs: ProviderPushResult) -> Bool {
        lhs.pushed == rhs.pushed && lhs.skipped == rhs.skipped &&
        lhs.failed.map(\.name) == rhs.failed.map(\.name)
    }
}

public protocol SecretProvider: Sendable {
    var id: String { get }
    var displayName: String { get }
    var requiredScopeKeys: [String] { get }

    func authToken() throws -> String
    func push(secrets: [Secret], target: ProviderTarget) async throws -> ProviderPushResult
    func pull(target: ProviderTarget) async throws -> [Secret]
}

public enum ProviderError: Error, CustomStringConvertible {
    case missingAuth(String)
    case missingScope(String)
    case http(status: Int, body: String)
    case unsupported(String)
    case transport(String)

    public var description: String {
        switch self {
        case .missingAuth(let p): return "missing auth for provider \(p)"
        case .missingScope(let k): return "missing required scope key: \(k)"
        case .http(let s, let b): return "HTTP \(s): \(b)"
        case .unsupported(let m): return "unsupported: \(m)"
        case .transport(let m): return "transport error: \(m)"
        }
    }
}

public final class ProviderRegistry: @unchecked Sendable {
    private var byId: [String: SecretProvider]

    public init(builtin: [SecretProvider] = []) {
        self.byId = Dictionary(uniqueKeysWithValues: builtin.map { ($0.id, $0) })
    }

    public func register(_ provider: SecretProvider) {
        byId[provider.id] = provider
    }

    public func provider(id: String) -> SecretProvider? { byId[id] }
    public var all: [SecretProvider] { Array(byId.values) }

    public static func defaults() -> ProviderRegistry {
        ProviderRegistry(builtin: [
            CloudflareProvider(),
            VercelProvider(),
            PushciProvider()
        ])
    }
}
