import SwiftUI
import VaultCore

struct CloudSyncRecoveryKeySection: View {
    @EnvironmentObject var env: AppEnvironment
    @Binding var recoveryRestoreKey: String
    let canUseRecoveryKey: Bool
    let canPreviewRecovery: Bool
    let canImportSelectedWithRecovery: Bool
    let status: AppCloudSyncStatus?
    let bundleInfo: CloudSyncBundleInfo?
    let recoveryErrorText: String?
    let onShow: (String) async -> Void
    let onCreate: () -> Void
    let onStopActive: () -> Void
    let onMakeActive: (String) -> Void
    let onRemoveRetained: (String) -> Void
    let onPreviewICloud: () -> Void
    let onChooseBackup: () -> Void
    let onImportSelected: () async -> Void
    let onKeepEntered: () -> Void
    let onMakeEnteredActive: () -> Void

    var body: some View {
        LabeledContent(
            "Recovery protection",
            value: env.cachedHasBackupRecoveryKey ? "Enabled for new backups" : "Not configured"
        )

        if env.cachedRecoveryKeys.isEmpty {
            Button(action: onCreate) {
                Label("Create recovery key", systemImage: "key.fill")
            }
            .buttonStyle(.borderedProminent)
            .accessibilityHint("Generate a recovery key for new encrypted backups.")
        } else {
            ForEach(env.cachedRecoveryKeys) { summary in
                CloudSyncRecoveryKeyRow(
                    summary: summary,
                    selectedBundleID: bundleInfo?.recoveryKeyID,
                    onShow: { Task { await onShow(summary.identifier) } },
                    onMakeActive: { onMakeActive(summary.identifier) },
                    onStopActive: onStopActive,
                    onRemove: { onRemoveRetained(summary.identifier) }
                )
            }
            Button(action: onCreate) {
                if env.cachedHasBackupRecoveryKey {
                    Label("Replace active key", systemImage: "arrow.triangle.2.circlepath")
                } else {
                    Label("Create recovery key", systemImage: "key.fill")
                }
            }
            .help(
                env.cachedHasBackupRecoveryKey
                    ? "Generate a new active key. The current key stays available for restores."
                    : "Generate a recovery key for new encrypted backups."
            )
        }

        CloudSyncRecoveryRestoreSection(
            recoveryRestoreKey: $recoveryRestoreKey,
            canUseRecoveryKey: canUseRecoveryKey,
            canPreviewRecovery: canPreviewRecovery,
            canImportSelectedWithRecovery: canImportSelectedWithRecovery,
            status: status,
            hasInstalledKeys: !env.cachedRecoveryKeys.isEmpty,
            bundleInfo: bundleInfo,
            recoveryErrorText: recoveryErrorText,
            onPreviewICloud: onPreviewICloud,
            onChooseBackup: onChooseBackup,
            onImportSelected: onImportSelected,
            onKeepEntered: onKeepEntered,
            onMakeEnteredActive: onMakeEnteredActive
        )
    }
}
