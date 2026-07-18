import AppKit
import Foundation
import VaultCore

extension AppEnvironment {
    var teamLicense: TeamLicense? { LicenseStore.load(prefs: prefs) }

    var isTeamLicensed: Bool { teamLicense?.isTeam == true }

    var licenseStatusLine: String {
        guard let lic = teamLicense else { return "Solo (free)" }
        if lic.isExpired { return "Team expired" }
        let seats = "\(lic.seats) seat\(lic.seats == 1 ? "" : "s")"
        return "Team · \(lic.email) · \(seats)"
    }

    func activateLicense(_ raw: String) throws {
        _ = try LicenseStore.activate(raw, prefs: prefs)
        objectWillChange.send()
        showToast("Team license activated", feedback: .success)
    }

    func deactivateLicense() {
        LicenseStore.deactivate(prefs: prefs)
        objectWillChange.send()
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
