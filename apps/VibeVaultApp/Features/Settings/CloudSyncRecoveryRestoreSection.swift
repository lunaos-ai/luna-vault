import SwiftUI
import VaultCore

struct CloudSyncRecoveryRestoreSection: View {
    @Binding var recoveryRestoreKey: String
    let canUseRecoveryKey: Bool
    let canPreviewRecovery: Bool
    let canImportSelectedWithRecovery: Bool
    let status: AppCloudSyncStatus?
    let hasInstalledKeys: Bool
    let bundleInfo: CloudSyncBundleInfo?
    let recoveryErrorText: String?
    let onPreviewICloud: () -> Void
    let onChooseBackup: () -> Void
    let onImportSelected: () async -> Void
    let onKeepEntered: () -> Void
    let onMakeEnteredActive: () -> Void

    var body: some View {
        DisclosureGroup("Restore with recovery key") {
            SecureField("VV-RK1 recovery key", text: $recoveryRestoreKey)
                .font(.system(.body, design: .monospaced))
                .textContentType(.password)
                .accessibilityLabel("Recovery key")
                .accessibilityHint("Paste or type the VV-RK1 recovery key originally used for this backup.")

            HStack {
                previewButton
                chooseButton
                importButton
            }

            HStack {
                Button(action: onKeepEntered) {
                    Label("Keep this key for restores", systemImage: "archivebox")
                }
                .disabled(!canUseRecoveryKey)
                .help(CloudSyncRecoveryAccess.keepForRestoresHelp(canUseKey: canUseRecoveryKey))
                .accessibilityHint(CloudSyncRecoveryAccess.keepForRestoresHelp(canUseKey: canUseRecoveryKey))

                Button(action: onMakeEnteredActive) {
                    Label("Make this the active key for new backups", systemImage: "key.icloud")
                }
                .disabled(!canUseRecoveryKey)
                .help(CloudSyncRecoveryAccess.makeActiveHelp(canUseKey: canUseRecoveryKey))
                .accessibilityHint(CloudSyncRecoveryAccess.makeActiveHelp(canUseKey: canUseRecoveryKey))
            }

            CloudSyncBundleInspectBlock(info: bundleInfo, errorText: recoveryErrorText)
        }
    }

    private var previewButton: some View {
        let help = CloudSyncRecoveryAccess.previewICloudHelp(
            canPreview: canPreviewRecovery,
            bundleExists: status?.bundleExists == true,
            canEnterKey: canUseRecoveryKey,
            hasInstalledKeys: hasInstalledKeys
        )
        return Button(action: onPreviewICloud) {
            Label("Preview iCloud", systemImage: "doc.text.magnifyingglass")
        }
        .disabled(!canPreviewRecovery)
        .help(help)
        .accessibilityHint(help)
    }

    private var chooseButton: some View {
        let help = CloudSyncRecoveryAccess.chooseBackupHelp(
            isWorking: false,
            canEnterKey: canUseRecoveryKey,
            hasInstalledKeys: hasInstalledKeys
        )
        return Button(action: onChooseBackup) {
            Label("Choose backup...", systemImage: "folder")
        }
        .disabled(!canUseRecoveryKey && !hasInstalledKeys)
        .help(help)
        .accessibilityHint(help)
    }

    private var importButton: some View {
        let help = CloudSyncRecoveryAccess.importHelp(
            canImport: canImportSelectedWithRecovery,
            hasPreview: bundleInfo != nil
        )
        return Button {
            Task { await onImportSelected() }
        } label: {
            Label("Import selected", systemImage: "square.and.arrow.down")
        }
        .disabled(!canImportSelectedWithRecovery)
        .help(help)
        .accessibilityHint(help)
    }
}
