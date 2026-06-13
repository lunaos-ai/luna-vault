import SwiftUI

struct BackupListView: View {
    @EnvironmentObject var cloudAuth: CloudAuthService
    @EnvironmentObject var cloudBackup: CloudBackupService
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            List {
                ForEach(cloudBackup.backups) { backup in
                    BackupRow(backup: backup)
                }
                .onDelete { indexSet in
                    Task {
                        for index in indexSet {
                            let backup = cloudBackup.backups[index]
                            _ = await cloudBackup.deleteBackup(backupId: backup.id)
                        }
                    }
                }
            }
            .navigationTitle("Cloud Backups")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .primaryAction) {
                    Button {
                        Task {
                            await cloudBackup.listBackups()
                        }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                }
            }
        }
        .onAppear {
            Task {
                await cloudBackup.listBackups()
            }
        }
    }
}
