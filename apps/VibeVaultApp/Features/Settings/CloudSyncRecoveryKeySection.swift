import SwiftUI

struct CloudSyncRecoveryKeySection: View {
    @EnvironmentObject var env: AppEnvironment
    @Binding var recoveryRestoreKey: String
    let canUseRecoveryKey: Bool
    let canImportSelectedWithRecovery: Bool
    let status: AppCloudSyncStatus?
    let selectedBackupURL: URL?
    let preview: AppCloudSyncPreview?
    let onShowInstalled: () async -> Void
    let onCreate: () -> Void
    let onConfirmRemove: () -> Void
    let onPreviewICloud: () -> Void
    let onChooseBackup: () -> Void
    let onImportSelected: () async -> Void
    let onSaveEnteredKey: () -> Void

    var body: some View {
        LabeledContent(
            "Recovery protection",
            value: env.cachedHasBackupRecoveryKey ? "Enabled for new backups" : "Not configured"
        )

        HStack {
            if env.cachedHasBackupRecoveryKey {
                Button {
                    Task { await onShowInstalled() }
                } label: {
                    Label("Show or export key", systemImage: "key.viewfinder")
                }

                Button {
                    onCreate()
                } label: {
                    Label("Replace key", systemImage: "arrow.triangle.2.circlepath")
                }

                Button(role: .destructive) {
                    onConfirmRemove()
                } label: {
                    Label("Remove", systemImage: "trash")
                }
            } else {
                Button {
                    onCreate()
                } label: {
                    Label("Create recovery key", systemImage: "key.fill")
                }
                .buttonStyle(.borderedProminent)
            }
        }

        DisclosureGroup("Restore with recovery key") {
            SecureField("VV-RK1 recovery key", text: $recoveryRestoreKey)
                .font(.system(.body, design: .monospaced))

            HStack {
                Button {
                    onPreviewICloud()
                } label: {
                    Label("Preview iCloud", systemImage: "doc.text.magnifyingglass")
                }
                .disabled(!canUseRecoveryKey || status?.bundleExists != true)

                Button {
                    onChooseBackup()
                } label: {
                    Label("Choose backup...", systemImage: "folder")
                }
                .disabled(!canUseRecoveryKey)

                Button {
                    Task { await onImportSelected() }
                } label: {
                    Label("Import selected", systemImage: "square.and.arrow.down")
                }
                .disabled(!canImportSelectedWithRecovery)
            }

            Button {
                onSaveEnteredKey()
            } label: {
                Label("Use this key for future backups", systemImage: "key.icloud")
            }
            .disabled(!canUseRecoveryKey)
        }
    }
}
