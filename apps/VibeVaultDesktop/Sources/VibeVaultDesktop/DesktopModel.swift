import Foundation
import VaultCore

struct DesktopModel {
    enum Tab: String, CaseIterable, Identifiable {
        case vault = "Vault"
        case unlock = "Unlock"
        case license = "License"
        var id: String { rawValue }
    }

    var tab: Tab = .vault
    var secretNames: [String] = []
    var selectedName: String?
    var revealedValue: String?
    var statusMessage = ""
    var errorMessage: String?
    var unlockMinutes = "30"
    var unlockRemaining = "Locked"
    var licenseKey = ""
    var licenseSummary = "Solo"
    var draftName = ""
    var draftValue = ""
    var draftNotes = ""
    var showAddForm = false

    mutating func clearFeedback() {
        errorMessage = nil
        statusMessage = ""
    }
}

enum DesktopVault {
    static func service() throws -> VaultService {
        try VaultService.live()
    }

    static func prefs() -> PreferenceStoring {
        KeychainPrefs()
    }
}
