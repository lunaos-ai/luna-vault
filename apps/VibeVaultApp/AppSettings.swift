import Foundation
import VaultCore

struct AppSettings: Codable, Equatable {
    var sessionMinutes: Double = 5
    var notificationsEnabled: Bool = true
    var warnWithinDays: Int = 14

    static func migrateLegacy(into prefs: PreferenceStoring, settingsKey: String) -> AppSettings {
        var s = AppSettings()
        let d = UserDefaults.standard
        let session = d.double(forKey: "vibe-vault.biometric.session-minutes")
        if session > 0 { s.sessionMinutes = session }
        if let on = d.object(forKey: "vibe-vault.notifications.enabled") as? Bool {
            s.notificationsEnabled = on
        }
        let warn = d.integer(forKey: "vibe-vault.notifications.warn-within-days")
        if warn > 0 { s.warnWithinDays = warn }
        prefs.setCodable(s, forKey: settingsKey)
        d.removeObject(forKey: "vibe-vault.biometric.session-minutes")
        d.removeObject(forKey: "vibe-vault.notifications.enabled")
        d.removeObject(forKey: "vibe-vault.notifications.warn-within-days")
        d.removeObject(forKey: "vibe-vault.delivered-alerts")
        return s
    }
}
