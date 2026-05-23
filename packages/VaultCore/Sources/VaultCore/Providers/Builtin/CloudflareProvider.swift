import Foundation

public final class CloudflareProvider: SecretProvider, @unchecked Sendable {
    public let id = "cloudflare"
    public let displayName = "Cloudflare Workers"
    public let requiredScopeKeys = ["account_id", "script_name"]

    private let session: URLSession
    private let tokenSource: () -> String?

    public init(
        session: URLSession = .shared,
        tokenSource: @escaping () -> String? = { ProcessInfo.processInfo.environment["CLOUDFLARE_API_TOKEN"] }
    ) {
        self.session = session
        self.tokenSource = tokenSource
    }

    public func authToken() throws -> String {
        guard let t = tokenSource(), !t.isEmpty else { throw ProviderError.missingAuth(id) }
        return t
    }

    public func push(secrets: [Secret], target: ProviderTarget) async throws -> ProviderPushResult {
        guard let account = target.scope["account_id"] else { throw ProviderError.missingScope("account_id") }
        guard let script = target.scope["script_name"] else { throw ProviderError.missingScope("script_name") }
        let token = try authToken()
        let url = URL(string: "https://api.cloudflare.com/client/v4/accounts/\(account)/workers/scripts/\(script)/secrets")!
        var pushed: [String] = []
        var failed: [(String, String)] = []
        for secret in secrets {
            var req = URLRequest(url: url)
            req.httpMethod = "PUT"
            req.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            req.addValue("application/json", forHTTPHeaderField: "Content-Type")
            let body: [String: Any] = ["name": secret.name, "text": secret.value, "type": "secret_text"]
            req.httpBody = try JSONSerialization.data(withJSONObject: body)
            do {
                let (data, resp) = try await session.data(for: req)
                guard let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
                    let body = String(data: data, encoding: .utf8) ?? ""
                    failed.append((secret.name, body))
                    continue
                }
                pushed.append(secret.name)
            } catch {
                failed.append((secret.name, "\(error)"))
            }
        }
        return ProviderPushResult(pushed: pushed, skipped: [], failed: failed)
    }

    public func pull(target: ProviderTarget) async throws -> [Secret] {
        // CF API returns only names + types for secrets; values cannot be retrieved.
        guard let account = target.scope["account_id"] else { throw ProviderError.missingScope("account_id") }
        guard let script = target.scope["script_name"] else { throw ProviderError.missingScope("script_name") }
        let token = try authToken()
        let url = URL(string: "https://api.cloudflare.com/client/v4/accounts/\(account)/workers/scripts/\(script)/secrets")!
        var req = URLRequest(url: url)
        req.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        let (data, resp) = try await session.data(for: req)
        guard let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            let body = String(data: data, encoding: .utf8) ?? ""
            throw ProviderError.http(status: (resp as? HTTPURLResponse)?.statusCode ?? -1, body: body)
        }
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let result = json["result"] as? [[String: Any]] else { return [] }
        return result.compactMap { item in
            guard let name = item["name"] as? String else { return nil }
            return Secret(name: name, value: "")
        }
    }
}
