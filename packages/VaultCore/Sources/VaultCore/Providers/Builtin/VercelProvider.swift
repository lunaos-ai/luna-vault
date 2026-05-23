import Foundation

public final class VercelProvider: SecretProvider, @unchecked Sendable {
    public let id = "vercel"
    public let displayName = "Vercel"
    public let requiredScopeKeys = ["project_id"]

    private let session: URLSession
    private let tokenSource: () -> String?

    public init(
        session: URLSession = .shared,
        tokenSource: @escaping () -> String? = { ProcessInfo.processInfo.environment["VERCEL_TOKEN"] }
    ) {
        self.session = session
        self.tokenSource = tokenSource
    }

    public func authToken() throws -> String {
        guard let t = tokenSource(), !t.isEmpty else { throw ProviderError.missingAuth(id) }
        return t
    }

    public func push(secrets: [Secret], target: ProviderTarget) async throws -> ProviderPushResult {
        guard let project = target.scope["project_id"] else { throw ProviderError.missingScope("project_id") }
        let token = try authToken()
        let teamQuery = target.scope["team_id"].map { "?teamId=\($0)" } ?? ""
        let url = URL(string: "https://api.vercel.com/v10/projects/\(project)/env\(teamQuery)")!
        var pushed: [String] = []
        var failed: [(String, String)] = []
        for secret in secrets {
            var req = URLRequest(url: url)
            req.httpMethod = "POST"
            req.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            req.addValue("application/json", forHTTPHeaderField: "Content-Type")
            let body: [String: Any] = [
                "key": secret.name,
                "value": secret.value,
                "type": "encrypted",
                "target": ["production", "preview", "development"]
            ]
            req.httpBody = try JSONSerialization.data(withJSONObject: body)
            do {
                let (data, resp) = try await session.data(for: req)
                let status = (resp as? HTTPURLResponse)?.statusCode ?? -1
                if (200..<300).contains(status) {
                    pushed.append(secret.name)
                } else {
                    failed.append((secret.name, String(data: data, encoding: .utf8) ?? ""))
                }
            } catch {
                failed.append((secret.name, "\(error)"))
            }
        }
        return ProviderPushResult(pushed: pushed, skipped: [], failed: failed)
    }

    public func pull(target: ProviderTarget) async throws -> [Secret] {
        guard let project = target.scope["project_id"] else { throw ProviderError.missingScope("project_id") }
        let token = try authToken()
        let teamQuery = target.scope["team_id"].map { "?teamId=\($0)&decrypt=true" } ?? "?decrypt=true"
        let url = URL(string: "https://api.vercel.com/v9/projects/\(project)/env\(teamQuery)")!
        var req = URLRequest(url: url)
        req.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        let (data, resp) = try await session.data(for: req)
        let status = (resp as? HTTPURLResponse)?.statusCode ?? -1
        guard (200..<300).contains(status) else {
            throw ProviderError.http(status: status, body: String(data: data, encoding: .utf8) ?? "")
        }
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let envs = json["envs"] as? [[String: Any]] else { return [] }
        return envs.compactMap { item in
            guard let key = item["key"] as? String else { return nil }
            let value = item["value"] as? String ?? ""
            return Secret(name: key, value: value)
        }
    }
}
