import Foundation

public enum LicenseStore {
    public static let rawKey = "team.license.raw"
    public static let payloadKey = "team.license.payload"

    /// Loads a license only after re-verifying the stored VV1 key.
    /// Unsigned / tampered payload alone never grants Team access.
    public static func load(prefs: PreferenceStoring) -> TeamLicense? {
        guard let raw = rawLicenseKey(prefs: prefs) else {
            if prefs.data(forKey: payloadKey) != nil { deactivate(prefs: prefs) }
            return nil
        }
        do {
            let license = try LicenseCodec.verify(raw)
            guard license.isLicensed else {
                deactivate(prefs: prefs)
                return nil
            }
            prefs.setCodable(license, forKey: payloadKey)
            return license
        } catch {
            deactivate(prefs: prefs)
            return nil
        }
    }

    public static func rawLicenseKey(prefs: PreferenceStoring) -> String? {
        guard let data = prefs.data(forKey: rawKey) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    public static func activate(_ raw: String, prefs: PreferenceStoring) throws -> TeamLicense {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        let license = try LicenseCodec.verify(trimmed)
        guard license.isLicensed else { throw LicenseError.notLicensed }
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
