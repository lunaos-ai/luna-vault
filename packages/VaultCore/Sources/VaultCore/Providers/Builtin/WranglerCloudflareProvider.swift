import Foundation

/// Cloudflare sync that authenticates through the user's installed `wrangler`
/// CLI (OAuth login) instead of a raw API token. Secret values are piped over
/// stdin to `wrangler secret bulk` — never passed as argv and never logged.
public final class WranglerCloudflareProvider: SecretProvider, @unchecked Sendable {
    public let id = "cloudflare-wrangler"
    public let displayName = "Cloudflare (Wrangler)"
    public let requiredScopeKeys = ["worker"]

    private let runner: ProcessRunner

    public init(runner: ProcessRunner = SystemProcessRunner()) {
        self.runner = runner
    }

    /// Auth is delegated to wrangler's stored OAuth session. We surface a clear
    /// error telling the user to run `wrangler login` when no session exists.
    public func authToken() throws -> String {
        let bin = try wranglerBinary()
        let res = try runner.run(executable: bin, args: ["whoami"], stdin: nil)
        guard res.exitCode == 0, res.stdout.lowercased().contains("logged in") else {
            throw ProviderError.missingAuth("cloudflare-wrangler — run `wrangler login`")
        }
        return "wrangler-oauth"
    }

    public func push(secrets: [Secret], target: ProviderTarget) async throws -> ProviderPushResult {
        guard let worker = target.scope["worker"], !worker.isEmpty else {
            throw ProviderError.missingScope("worker")
        }
        _ = try authToken()
        let bin = try wranglerBinary()

        var payload: [String: String] = [:]
        for s in secrets { payload[s.name] = s.value }
        let json = try JSONSerialization.data(withJSONObject: payload)

        let res = try runner.run(
            executable: bin,
            args: ["secret", "bulk", "--name", worker],
            stdin: json
        )
        guard res.exitCode == 0 else {
            let reason = (res.stderr.isEmpty ? res.stdout : res.stderr)
            return ProviderPushResult(pushed: [], skipped: [], failed: secrets.map { ($0.name, reason) })
        }
        return ProviderPushResult(pushed: secrets.map(\.name), skipped: [], failed: [])
    }

    /// Lists the secret *names* already bound to the worker (values are never
    /// returned by Cloudflare). Doubles as the "fetch compute state" probe.
    public func pull(target: ProviderTarget) async throws -> [Secret] {
        guard let worker = target.scope["worker"], !worker.isEmpty else {
            throw ProviderError.missingScope("worker")
        }
        let bin = try wranglerBinary()
        let res = try runner.run(
            executable: bin,
            args: ["secret", "list", "--name", worker],
            stdin: nil
        )
        guard res.exitCode == 0 else {
            throw ProviderError.transport("wrangler exit \(res.exitCode): \(res.stderr.isEmpty ? res.stdout : res.stderr)")
        }
        return parseSecretList(res.stdout).map { Secret(name: $0, value: "") }
    }

    func parseSecretList(_ stdout: String) -> [String] {
        // wrangler emits a JSON array of { "name": ..., "type": ... }.
        guard let start = stdout.firstIndex(of: "["),
              let data = String(stdout[start...]).data(using: .utf8),
              let arr = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else { return [] }
        return arr.compactMap { $0["name"] as? String }
    }

    private func wranglerBinary() throws -> String {
        if let found = WranglerLocator.resolve() { return found }
        throw ProviderError.unsupported("wrangler not found — install with `npm i -g wrangler`")
    }
}

/// Locates the `wrangler` executable across the locations a sandboxed GUI app
/// won't have on its default PATH (nvm, Homebrew, global npm).
public enum WranglerLocator {
    public static func resolve() -> String? {
        let fm = FileManager.default
        var candidates: [String] = []

        let path = ProcessInfo.processInfo.environment["PATH"] ?? ""
        for dir in path.split(separator: ":") { candidates.append("\(dir)/wrangler") }

        candidates.append(contentsOf: [
            "/opt/homebrew/bin/wrangler",
            "/usr/local/bin/wrangler"
        ])

        let home = fm.homeDirectoryForCurrentUser.path
        let nvmRoot = "\(home)/.nvm/versions/node"
        if let versions = try? fm.contentsOfDirectory(atPath: nvmRoot) {
            for v in versions.sorted().reversed() {
                candidates.append("\(nvmRoot)/\(v)/bin/wrangler")
            }
        }

        return candidates.first { fm.isExecutableFile(atPath: $0) }
    }
}
