import Foundation

/// Resolves PushCI cloud auth + API base URL from env or `~/.pushci/config.json`.
public enum PushciConfig {
    public static let defaultAPIBase = "https://api.pushci.dev"

    public static func apiBase(
        env: [String: String] = ProcessInfo.processInfo.environment
    ) -> String {
        let raw = env["PUSHCI_API_BASE"]?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let raw, !raw.isEmpty { return raw.trimmingCharacters(in: CharacterSet(charactersIn: "/")) }
        return defaultAPIBase
    }

    /// Prefer `PUSHCI_TOKEN`, then Keychain prefs, then `~/.pushci/config.json` `token`.
    public static func cloudToken(
        prefs: PreferenceStoring? = nil,
        env: [String: String] = ProcessInfo.processInfo.environment,
        home: URL? = nil,
        fileManager: FileManager = .default
    ) -> String? {
        if let envTok = firstEnv(env, ["PUSHCI_TOKEN", "PUSHCI_JWT"]), !envTok.isEmpty {
            return envTok
        }
        if let prefs, let stored = ProviderCredentialStore.pushciToken(prefs: prefs) {
            return stored
        }
        return loadCLIConfigToken(home: home, fileManager: fileManager)
    }

    public static func loadCLIConfigToken(
        home: URL? = nil,
        fileManager: FileManager = .default
    ) -> String? {
        let homeURL = home ?? fileManager.homeDirectoryForCurrentUser
        let path = homeURL.appendingPathComponent(".pushci/config.json")
        guard let data = try? Data(contentsOf: path),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let token = json["token"] as? String
        else { return nil }
        let trimmed = token.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private static func firstEnv(_ env: [String: String], _ names: [String]) -> String? {
        for name in names {
            let value = env[name]?.trimmingCharacters(in: .whitespacesAndNewlines)
            if let value, !value.isEmpty { return value }
        }
        return nil
    }
}
