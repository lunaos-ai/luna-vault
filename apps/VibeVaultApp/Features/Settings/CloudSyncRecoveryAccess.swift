import Foundation
import VaultCore

enum CloudSyncRecoveryAccess {
    static func previewICloudHelp(
        canPreview: Bool,
        bundleExists: Bool,
        canEnterKey: Bool,
        hasInstalledKeys: Bool
    ) -> String {
        if canPreview {
            return "Preview the iCloud bundle without importing secrets or changing keys."
        }
        if !bundleExists { return "No iCloud bundle is present to preview." }
        if !canEnterKey && !hasInstalledKeys {
            return "Enter a valid VV-RK1 recovery key, or install a recovery key first."
        }
        return "Wait for the current operation to finish."
    }

    static func chooseBackupHelp(isWorking: Bool, canEnterKey: Bool, hasInstalledKeys: Bool) -> String {
        if isWorking { return "Wait for the current operation to finish." }
        if !canEnterKey && !hasInstalledKeys {
            return "Enter a valid VV-RK1 recovery key, or install a recovery key first."
        }
        return "Choose a .vvsync backup to preview without importing."
    }

    static func importHelp(canImport: Bool, hasPreview: Bool) -> String {
        if canImport { return "Import the previewed backup into this vault." }
        if !hasPreview { return "Preview a backup successfully before importing." }
        return "Import is unavailable until a recovery preview succeeds."
    }

    static func keepForRestoresHelp(canUseKey: Bool) -> String {
        if canUseKey { return "Store this key for restoring older backups without making it active." }
        return "Enter a valid VV-RK1 recovery key first."
    }

    static func makeActiveHelp(canUseKey: Bool) -> String {
        if canUseKey { return "Use this key for new backups. The current active key stays available for restores." }
        return "Enter a valid VV-RK1 recovery key first."
    }

    static func matchLabel(_ status: RecoveryKeyMatchStatus) -> String {
        switch status {
        case .unprotected: return "This backup has no recovery-key protection."
        case .matchedActive: return "Matches the installed active key."
        case .matchedRetained: return "Matches an installed key kept for restores."
        case .notInstalled: return "Required key is not installed."
        case .legacyUnknown: return CloudSyncRecoveryCopy.legacyIdentityUnavailable
        }
    }

    static func matchLabel(info: CloudSyncBundleInfo, keys: [RecoveryKeySummary]) -> String {
        guard info.hasRecoveryProtection else { return matchLabel(.unprotected) }
        guard let identifier = info.recoveryKeyID else { return matchLabel(.legacyUnknown) }
        guard let summary = keys.first(where: { $0.identifier == identifier }) else {
            return matchLabel(.notInstalled)
        }
        return matchLabel(summary.isActive ? .matchedActive : .matchedRetained)
    }
}
