import Foundation
import VaultCore

struct DesktopModel {
    enum Tab: String, CaseIterable, Identifiable {
        case vault = "Vault"
        case unlock = "Unlock"
        case sync = "Sync"
        case sandbox = "Sandbox"
        case audit = "Audit"
        case license = "License"
        var id: String { rawValue }
    }

    var tab: Tab = .vault
    var secretNames: [String] = []
    var selectedName: String?
    var revealedValue: String?
    var selectedNotes: String?
    var selectedMCPAllowed = false
    var search = ""
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
    var syncPath = ""
    var syncPassphrase = ""
    var syncOverwrite = true
    var passkey = ""
    var passkeyConfirm = ""
    var sandboxMinutes = "30"
    var sandboxStatus = "Stopped"
    var auditLines: [String] = []

    var visibleSecretNames: [String] {
        let query = search.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return secretNames }
        return secretNames.filter { $0.localizedCaseInsensitiveContains(query) }
    }

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
