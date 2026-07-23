import AppKit
import Foundation
import VaultCore

extension AppEnvironment {
    /// One Keychain hit per credential, then memory — SwiftUI must not re-query on every paint.
    func reloadProviderCaches() {
        let env = ProcessInfo.processInfo.environment
        cachedHasCloudflareToken =
            ProviderCredentialStore.cloudflareToken(prefs: prefs) != nil
            || ProviderCredentialStore.cloudflareEnvironmentToken(env: env) != nil
        cachedHasVercelToken =
            ProviderCredentialStore.vercelToken(prefs: prefs) != nil
            || env["VERCEL_TOKEN"]?.isEmpty == false
        cachedTeamLicense = LicenseStore.load(prefs: prefs)
    }

    var hasCloudflareToken: Bool { cachedHasCloudflareToken }
    var hasVercelToken: Bool { cachedHasVercelToken }
    var teamLicense: TeamLicense? { cachedTeamLicense }
    var isTeamLicensed: Bool { cachedTeamLicense?.isLicensed == true }

    var licenseStatusLine: String {
        guard let lic = cachedTeamLicense, lic.isLicensed else { return "Solo (free)" }
        let seats = "\(lic.seats) seat\(lic.seats == 1 ? "" : "s")"
        return "\(lic.tier.capitalized) · \(lic.email) · \(seats)"
    }

    func activateLicense(_ raw: String) throws {
        cachedTeamLicense = try LicenseStore.activate(raw, prefs: prefs)
        showToast("Team license activated", feedback: .success)
    }

    func deactivateLicense() {
        LicenseStore.deactivate(prefs: prefs)
        cachedTeamLicense = nil
        showToast("License removed", feedback: .tick)
    }

    func openTeamCheckout() {
        let url = LemonSqueezyConfig.checkoutURL(prefs: prefs)
        NSWorkspace.shared.open(url)
    }

    func setLemonCheckoutURL(_ url: String) {
        LemonSqueezyConfig.setCheckoutURL(url.isEmpty ? nil : url, prefs: prefs)
    }
}
