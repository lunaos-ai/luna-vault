import Foundation
import SwiftUI
import VaultCore

struct CloudSyncBackupSection: View {
    @EnvironmentObject var env: AppEnvironment
    @Binding var showExportBackupSheet: Bool
    @Binding var showImportBackupSheet: Bool
    let isWorking: Bool
    let canSyncToICloud: Bool
    let canRunManagedBackup: Bool
    let canPreview: Bool
    let status: AppCloudSyncStatus?
    let backupHistory: [CloudBackupFile]
    let preview: AppCloudSyncPreview?
    let onPreviewBackup: (URL) -> Void
    let onBackupNow: () async -> Void
    let onEnable: () -> Void
    let onDisable: () -> Void
    let onPrune: () -> Void

    private var automaticBackupStatus: String {
        guard env.automaticBackupsEnabled else { return "Off" }
        return env.automaticBackupCredentialAvailable() ? "Enabled" : "Needs passphrase"
    }

    var body: some View {
        HStack {
            Button {
                showExportBackupSheet = true
            } label: {
                Label("Export encrypted backup...", systemImage: "externaldrive.badge.plus")
            }
            .disabled(isWorking)

            Button {
                showImportBackupSheet = true
            } label: {
                Label("Import encrypted backup...", systemImage: "square.and.arrow.down")
            }
            .disabled(isWorking)
        }

        LabeledContent(
            "Automatic backups",
            value: automaticBackupStatus
        )
        Picker("Frequency", selection: $env.backupIntervalHours) {
            Text("Every hour").tag(1)
            Text("Every 6 hours").tag(6)
            Text("Every 12 hours").tag(12)
            Text("Daily").tag(24)
            Text("Weekly").tag(168)
        }
        .disabled(!env.automaticBackupsEnabled)

        Stepper(
            "Keep \(env.backupRetentionCount) backup\(env.backupRetentionCount == 1 ? "" : "s")",
            value: $env.backupRetentionCount,
            in: 1...100
        )

        LabeledContent(
            "Last managed backup",
            value: env.lastManagedBackupAt?.formatted(date: .abbreviated, time: .shortened) ?? "Never"
        )

        HStack {
            if env.automaticBackupsEnabled {
                Button(role: .destructive) {
                    onDisable()
                } label: {
                    Label("Disable schedule", systemImage: "calendar.badge.minus")
                }
            } else {
                Button {
                    onEnable()
                } label: {
                    Label("Enable schedule", systemImage: "calendar.badge.plus")
                }
                .disabled(!canSyncToICloud)
            }

            Button {
                Task { await onBackupNow() }
            } label: {
                Label("Back up now", systemImage: "clock.arrow.circlepath")
            }
            .disabled(!canRunManagedBackup)

            Button {
                onPrune()
            } label: {
                Label("Apply retention", systemImage: "trash.slash")
            }
            .disabled(isWorking || backupHistory.isEmpty)
        }

        if !backupHistory.isEmpty {
            DisclosureGroup("Backup history (\(backupHistory.count))") {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(backupHistory.prefix(10)) { backup in
                        Button {
                            onPreviewBackup(backup.url)
                        } label: {
                            HStack {
                                Image(systemName: "lock.doc")
                                Text(backup.createdAt.formatted(date: .abbreviated, time: .shortened))
                                Spacer()
                                Text(ByteCountFormatter.string(fromByteCount: backup.size, countStyle: .file))
                                    .foregroundStyle(Tokens.Text.secondary)
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .disabled(!canPreview)
                    }
                }
                .padding(.top, 4)
            }
        }

        if let preview {
            VStack(alignment: .leading, spacing: 8) {
                LabeledContent("Selected bundle", value: preview.path)
                LabeledContent("Source Mac", value: preview.sourceHost)
                LabeledContent("Exported", value: preview.exportedAtText)
                LabeledContent("Secrets", value: "\(preview.secretCount)")
                LabeledContent("Saved versions", value: "\(preview.revisionCount)")
                LabeledContent("Authenticators", value: "\(preview.authenticatorCount)")
                LabeledContent("Size", value: preview.sizeText)
                LabeledContent("New locally", value: "\(preview.newCount)")
                LabeledContent("Backup is newer", value: "\(preview.backupNewerCount)")
                LabeledContent("Local is newer", value: "\(preview.localNewerCount)")
                LabeledContent("Same timestamp", value: "\(preview.sameTimestampCount)")
            }
            .font(.caption)
            .textSelection(.enabled)
        }

        if let status {
            Text(status.path)
                .font(.caption)
                .foregroundStyle(Tokens.Text.secondary)
                .textSelection(.enabled)
        }
    }
}
