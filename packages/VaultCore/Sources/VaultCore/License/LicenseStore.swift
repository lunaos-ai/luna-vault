import Foundation

public enum LicenseStore {
    public static let rawKey = "team.license.raw"
    public static let payloadKey = "team.license.payload"

    public static func load(prefs: PreferenceStoring) -> TeamLicense? {
        guard let lic = prefs.codable(TeamLicense.self, forKey: payloadKey) else { return nil }
        if lic.isExpired { return nil }
        return lic
    }

    public static func rawLicenseKey(prefs: PreferenceStoring) -> String? {
        guard let data = prefs.data(forKey: rawKey) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    public static func activate(_ raw: String, prefs: PreferenceStoring) throws -> TeamLicense {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        let license = try LicenseCodec.verify(trimmed)
        prefs.set(trimmed.data(using: .utf8), forKey: rawKey)
        prefs.setCodable(license, forKey: payloadKey)
        return license
    }

    public static func deactivate(prefs: PreferenceStoring) {
        prefs.set(nil, forKey: rawKey)
        prefs.set(nil, forKey: payloadKey)
    }

    /// Re-verify stored key (detect tampering / rotation).
    public static func refresh(prefs: PreferenceStoring) throws -> TeamLicense? {
        guard let raw = rawLicenseKey(prefs: prefs) else { return nil }
        return try activate(raw, prefs: prefs)
    }
}
