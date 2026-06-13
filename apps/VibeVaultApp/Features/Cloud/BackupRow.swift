import SwiftUI

struct BackupRow: View {
    let backup: CloudBackupService.CloudBackup
    @State private var showRestoreConfirm = false

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(backup.deviceName)
                    .font(.system(.body, design: .monospaced))
                Text(backup.createdAt, style: .date)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text(ByteCountFormatter.string(fromByteCount: Int64(backup.size), countStyle: .file))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button(role: .destructive) {
                Task {
                    _ = await CloudBackupService.shared.deleteBackup(backupId: backup.id)
                }
            } label: {
                Label("Delete", systemImage: "trash")
            }

            Button {
                showRestoreConfirm = true
            } label: {
                Label("Restore", systemImage: "arrow.counterclockwise")
            }
            .tint(.blue)
        }
        .confirmationDialog("Restore this backup?", isPresented: $showRestoreConfirm, titleVisibility: .visible) {
            Button("Restore", role: .destructive) {
                Task {
                    // Restore backup
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will replace your current secrets with the backup from \(backup.createdAt, style: .date).")
        }
    }
}
