import Foundation

public enum ProviderCredentialStore {
    public static let cloudflareTokenKey = "cloudflare.api_token"
    public static let vercelTokenKey = "vercel.api_token"

    public static func cloudflareToken(prefs: PreferenceStoring) -> String? {
        token(forKey: cloudflareTokenKey, prefs: prefs)
    }

    public static func setCloudflareToken(_ token: String?, prefs: PreferenceStoring) {
        setToken(token, forKey: cloudflareTokenKey, prefs: prefs)
    }

    public static func vercelToken(prefs: PreferenceStoring) -> String? {
        token(forKey: vercelTokenKey, prefs: prefs)
    }

    public static func setVercelToken(_ token: String?, prefs: PreferenceStoring) {
        setToken(token, forKey: vercelTokenKey, prefs: prefs)
    }

    private static func token(forKey key: String, prefs: PreferenceStoring) -> String? {
        guard let data = prefs.data(forKey: key) else { return nil }
        return String(data: data, encoding: .utf8)?.nilIfEmpty
    }

    private static func setToken(_ token: String?, forKey key: String, prefs: PreferenceStoring) {
        prefs.set(token?.data(using: .utf8), forKey: key)
    }
}

private extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}
