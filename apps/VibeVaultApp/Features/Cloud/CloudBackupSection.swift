import SwiftUI

struct CloudBackupSection: View {
    @EnvironmentObject var cloudAuth: CloudAuthService
    @EnvironmentObject var cloudBackup: CloudBackupService
    @Binding var showBackupList: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.md) {
            Text("Cloud Backup")
                .font(.headline)

            if cloudAuth.backupEnabled {
                VStack(spacing: Tokens.Space.md) {
                    lastBackupRow
                    Divider()
                    scheduledBackupRow
                    Divider()
                    viewBackupsButton
                }
                .padding()
                .glassCard(radius: Tokens.Radius.md, elevation: .resting)
            } else {
                HStack {
                    Image(systemName: "lock.fill")
                        .foregroundStyle(Tokens.Text.tertiary)
                    Text("Subscribe to enable cloud backups")
                        .font(.subheadline)
                        .foregroundStyle(Tokens.Text.secondary)
                    Spacer()
                }
                .padding()
                .glassCard(radius: Tokens.Radius.md, elevation: .resting)
            }
        }
    }

    private var lastBackupRow: some View {
        HStack {
            VStack(alignment: .leading, spacing: Tokens.Space.xs) {
                Text("Last Backup")
                    .font(.caption)
                    .foregroundStyle(Tokens.Text.secondary)
                if let lastBackup = cloudBackup.lastBackupDate {
                    Text(lastBackup, style: .relative)
                        .font(.subheadline)
                } else {
                    Text("Never")
                        .font(.subheadline)
                        .foregroundStyle(Tokens.Text.tertiary)
                }
            }

            Spacer()

            Button {
                Task {
                    // Trigger manual backup
                    // Need to get secrets from service
                }
            } label: {
                Label("Backup Now", systemImage: "arrow.clockwise")
            }
            .buttonStyle(.glassProminent)
        }
    }

    private var scheduledBackupRow: some View {
        HStack {
            VStack(alignment: .leading, spacing: Tokens.Space.xs) {
                Text("Scheduled Backup")
                    .font(.caption)
                    .foregroundStyle(Tokens.Text.secondary)
                if cloudBackup.isBackupScheduled, let nextBackup = cloudBackup.nextScheduledBackup {
                    Text("Next: \(nextBackup, style: .relative)")
                        .font(.subheadline)
                } else {
                    Text("Not scheduled")
                        .font(.subheadline)
                        .foregroundStyle(Tokens.Text.tertiary)
                }
            }

            Spacer()

            Button {
                // Show schedule picker
            } label: {
                Image(systemName: "gear")
            }
            .buttonStyle(.glass)
        }
    }

    private var viewBackupsButton: some View {
        Button {
            showBackupList = true
        } label: {
            HStack {
                Image(systemName: "archivebox")
                Text("View Backups")
                Spacer()
                Text("\(cloudBackup.backups.count)")
                    .foregroundStyle(Tokens.Text.tertiary)
                Image(systemName: "chevron.right")
            }
        }
        .buttonStyle(.glass)
    }
}
