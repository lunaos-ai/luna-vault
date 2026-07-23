import Foundation

public final class CloudflareProvider: SecretProvider, @unchecked Sendable {
    public let id = "cloudflare"
    public let displayName = "Cloudflare Workers"
    public let requiredScopeKeys = ["account_id", "script_name"]

    private let session: URLSession
    private let tokenSource: () -> String?

    public init(
        session: URLSession = .shared,
        tokenSource: @escaping () -> String? = { ProviderCredentialStore.cloudflareEnvironmentToken() }
    ) {
        self.session = session
        self.tokenSource = tokenSource
    }

    public func authToken() throws -> String {
        guard let token = tokenSource()?.trimmingCharacters(in: .whitespacesAndNewlines), !token.isEmpty else {
            throw ProviderError.missingAuth(id)
        }
        return token
    }

    public func push(secrets: [Secret], target: ProviderTarget) async throws -> ProviderPushResult {
        guard let account = cleanScope(target.scope["account_id"]) else { throw ProviderError.missingScope("account_id") }
        guard let script = cleanScope(target.scope["script_name"]) else { throw ProviderError.missingScope("script_name") }
        let token = try authToken()
        let url = try secretsURL(accountId: account, scriptName: script)
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
                guard let http = resp as? HTTPURLResponse else {
                    failed.append((secret.name, "missing HTTP response"))
                    continue
                }
                guard (200..<300).contains(http.statusCode), cloudflareSucceeded(data) else {
                    failed.append((secret.name, cloudflareError(data: data, status: http.statusCode)))
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
        guard let account = cleanScope(target.scope["account_id"]) else { throw ProviderError.missingScope("account_id") }
        guard let script = cleanScope(target.scope["script_name"]) else { throw ProviderError.missingScope("script_name") }
        let token = try authToken()
        let url = try secretsURL(accountId: account, scriptName: script)
        var req = URLRequest(url: url)
        req.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        let (data, resp) = try await session.data(for: req)
        guard let http = resp as? HTTPURLResponse else {
            throw ProviderError.transport("missing HTTP response")
        }
        guard (200..<300).contains(http.statusCode), cloudflareSucceeded(data) else {
            throw ProviderError.http(status: http.statusCode, body: cloudflareError(data: data, status: http.statusCode))
        }
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let result = json["result"] as? [[String: Any]] else { return [] }
        return result.compactMap { item in
            guard let name = item["name"] as? String else { return nil }
            return Secret(name: name, value: "")
        }
    }

    private func secretsURL(accountId: String, scriptName: String) throws -> URL {
        let escapedAccount = try pathComponent(accountId, label: "account_id")
        let escapedScript = try pathComponent(scriptName, label: "script_name")
        guard let url = URL(string: "https://api.cloudflare.com/client/v4/accounts/\(escapedAccount)/workers/scripts/\(escapedScript)/secrets") else {
            throw ProviderError.missingScope("account_id + script_name")
        }
        return url
    }

    private func cleanScope(_ value: String?) -> String? {
        let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed?.isEmpty == false ? trimmed : nil
    }

    private func pathComponent(_ value: String, label: String) throws -> String {
        var allowed = CharacterSet.urlPathAllowed
        allowed.remove(charactersIn: "/?#[]@!$&'()*+,;=")
        guard let escaped = value.addingPercentEncoding(withAllowedCharacters: allowed), !escaped.isEmpty else {
            throw ProviderError.missingScope(label)
        }
        return escaped
    }

    private func cloudflareSucceeded(_ data: Data) -> Bool {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let success = json["success"] as? Bool
        else { return true }
        return success
    }

    private func cloudflareError(data: Data, status: Int) -> String {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return String(data: data, encoding: .utf8) ?? "HTTP \(status)"
        }
        if let errors = json["errors"] as? [[String: Any]], !errors.isEmpty {
            return errors.compactMap { error in
                if let message = error["message"] as? String { return message }
                return nil
            }.joined(separator: "; ")
        }
        if let message = json["message"] as? String { return message }
        return String(data: data, encoding: .utf8) ?? "HTTP \(status)"
    }
}
