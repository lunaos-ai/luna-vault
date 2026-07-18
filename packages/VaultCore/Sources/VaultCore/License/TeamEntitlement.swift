import Foundation

/// Service-layer Team gate. UI must not be the only check — call this from VaultCore
/// and CLI before any Team-only capability.
public enum TeamEntitlement {
    public static func current(prefs: PreferenceStoring) -> TeamLicense? {
        LicenseStore.load(prefs: prefs)
    }

    public static func isLicensed(prefs: PreferenceStoring) -> Bool {
        current(prefs: prefs)?.isLicensed == true
    }

    @discardableResult
    public static func requireLicensed(prefs: PreferenceStoring) throws -> TeamLicense {
        guard let lic = current(prefs: prefs), lic.isLicensed else {
            throw LicenseError.notLicensed
        }
        return lic
    }
}
