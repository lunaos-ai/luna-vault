import Foundation
import SwiftUI
import VaultCore
import CryptoKit

/// Cloud backup service for Vibe Vault
/// Handles encrypted cloud backups, restores, and scheduling
@MainActor
final class CloudBackupService: ObservableObject {
    static let shared = CloudBackupService()

    @Published var backups: [CloudBackup] = []
    @Published var isLoading = false
    @Published var lastError: String?
    @Published var lastBackupDate: Date?
    @Published var nextScheduledBackup: Date?
    @Published var isBackupScheduled = false

    let apiBaseURL = "https://vibevault-api.your-account.workers.dev" // Update this
    let authService = CloudAuthService.shared

    private var backupTimer: Timer?

    private init() {
        loadLocalSchedule()
        startBackupTimer()
    }

    // MARK: - Backup Timer

    private func startBackupTimer() {
        // Check every hour if a scheduled backup is due
        backupTimer = Timer.scheduledTimer(withTimeInterval: 3600, repeats: true) { _ in
            Task {
                await self.checkScheduledBackup()
            }
        }
    }

    private func checkScheduledBackup() async {
        guard isBackupScheduled,
              let nextBackup = nextScheduledBackup,
              nextBackup <= Date(),
              authService.isAuthenticated,
              authService.backupEnabled else { return }

        // Trigger backup
        // This would need access to the secrets from VaultService
        // For now, we just update the schedule
        await getSchedule()
    }
}
