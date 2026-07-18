import Foundation

/// Lemon Squeezy checkout + store config (no API phone-home in the app).
public enum LemonSqueezyConfig {
    public static let defaultCheckoutURL =
        "https://vibevault.lunaos.ai/#pricing"

    public static func checkoutURL(prefs: PreferenceStoring? = nil) -> URL {
        if let env = ProcessInfo.processInfo.environment["VIBEVAULT_LS_CHECKOUT"],
           let url = URL(string: env), !env.isEmpty {
            return url
        }
        if let prefs,
           let data = prefs.data(forKey: "lemonsqueezy.checkout_url"),
           let s = String(data: data, encoding: .utf8),
           let url = URL(string: s), !s.isEmpty {
            return url
        }
        return URL(string: defaultCheckoutURL)!
    }

    public static func setCheckoutURL(_ url: String?, prefs: PreferenceStoring) {
        prefs.set(url?.data(using: .utf8), forKey: "lemonsqueezy.checkout_url")
    }

    public static var isConfigured: Bool {
        let u = checkoutURL().absoluteString
        return !u.contains("REPLACE_VARIANT_ID")
    }
}
