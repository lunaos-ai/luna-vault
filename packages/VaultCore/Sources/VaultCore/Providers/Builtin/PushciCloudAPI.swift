import Foundation

/// HTTPS client for PushCI project secrets (`/api/projects/:id/secrets`).
public struct PushciCloudAPI: Sendable {
    public let apiBase: String
    private let session: URLSession

    public init(apiBase: String = PushciConfig.defaultAPIBase, session: URLSession = .shared) {
        self.apiBase = apiBase.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        self.session = session
    }

    public func listSecretNames(projectId: String, token: String) async throws -> [String] {
        let url = try secretsCollectionURL(projectId: projectId)
        var req = URLRequest(url: url)
        req.httpMethod = "GET"
        req.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        let (data, resp) = try await session.data(for: req)
        let status = (resp as? HTTPURLResponse)?.statusCode ?? -1
        guard (200..<300).contains(status) else {
            throw ProviderError.http(status: status, body: safeBody(data))
        }
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let secrets = json["secrets"] as? [[String: Any]]
        else { return [] }
        return secrets.compactMap { $0["name"] as? String }
    }

    public func putSecret(
        projectId: String,
        name: String,
        value: String,
        environment: String,
        token: String
    ) async throws {
        let url = try secretURL(projectId: projectId, name: name)
        var req = URLRequest(url: url)
        req.httpMethod = "PUT"
        req.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        req.addValue("application/json", forHTTPHeaderField: "Content-Type")
        let body: [String: String] = ["value": value, "environment": environment]
        req.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (data, resp) = try await session.data(for: req)
        let status = (resp as? HTTPURLResponse)?.statusCode ?? -1
        guard (200..<300).contains(status) else {
            throw ProviderError.http(status: status, body: safeBody(data))
        }
    }

    /// Merges names into execution policy `ci_secret_names` (CI job allowlist).
    public func allowlistCISecrets(
        projectId: String,
        names: [String],
        token: String
    ) async throws {
        guard !names.isEmpty else { return }
        let url = try executionURL(projectId: projectId)
        var get = URLRequest(url: url)
        get.httpMethod = "GET"
        get.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        let (data, resp) = try await session.data(for: get)
        let status = (resp as? HTTPURLResponse)?.statusCode ?? -1
        guard (200..<300).contains(status),
              let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              var policy = json["policy"] as? [String: Any]
        else {
            throw ProviderError.http(status: status, body: safeBody(data))
        }
        var ci = Set((policy["ci_secret_names"] as? [String]) ?? [])
        names.forEach { ci.insert($0) }
        policy["ci_secret_names"] = Array(ci).sorted()
        var put = URLRequest(url: url)
        put.httpMethod = "PUT"
        put.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        put.addValue("application/json", forHTTPHeaderField: "Content-Type")
        put.httpBody = try JSONSerialization.data(withJSONObject: policy)
        let (putData, putResp) = try await session.data(for: put)
        let putStatus = (putResp as? HTTPURLResponse)?.statusCode ?? -1
        guard (200..<300).contains(putStatus) else {
            throw ProviderError.http(status: putStatus, body: safeBody(putData))
        }
    }

    private func secretsCollectionURL(projectId: String) throws -> URL {
        let id = try pathComponent(projectId, label: "project_id")
        guard let url = URL(string: "\(apiBase)/api/projects/\(id)/secrets") else {
            throw ProviderError.missingScope("project_id")
        }
        return url
    }

    private func secretURL(projectId: String, name: String) throws -> URL {
        let id = try pathComponent(projectId, label: "project_id")
        let n = try pathComponent(name.uppercased(), label: "name")
        guard let url = URL(string: "\(apiBase)/api/projects/\(id)/secrets/\(n)") else {
            throw ProviderError.missingScope("project_id")
        }
        return url
    }

    private func executionURL(projectId: String) throws -> URL {
        let id = try pathComponent(projectId, label: "project_id")
        guard let url = URL(string: "\(apiBase)/api/projects/\(id)/execution") else {
            throw ProviderError.missingScope("project_id")
        }
        return url
    }

    private func pathComponent(_ value: String, label: String) throws -> String {
        var allowed = CharacterSet.urlPathAllowed
        allowed.remove(charactersIn: "/?#[]@!$&'()*+,;=")
        guard let escaped = value.addingPercentEncoding(withAllowedCharacters: allowed),
              !escaped.isEmpty
        else { throw ProviderError.missingScope(label) }
        return escaped
    }

    /// Never echo secret values; truncate opaque HTTP error bodies.
    private func safeBody(_ data: Data) -> String {
        let raw = String(data: data, encoding: .utf8) ?? "HTTP error"
        if raw.count <= 240 { return raw }
        return String(raw.prefix(240)) + "…"
    }
}
