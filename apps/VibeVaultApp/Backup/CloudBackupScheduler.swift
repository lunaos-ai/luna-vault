import Foundation
import VaultCore

@MainActor
final class CloudBackupScheduler {
    private let lastBackupProvider: () -> Date?
    private let backupAction: () async -> Bool
    private var timer: Timer?
    private var intervalHours = 24
    private var isRunning = false

    init(
        lastBackupProvider: @escaping () -> Date?,
        backupAction: @escaping () async -> Bool
    ) {
        self.lastBackupProvider = lastBackupProvider
        self.backupAction = backupAction
    }

    func start(intervalHours: Int) {
        stop()
        self.intervalHours = max(1, intervalHours)
        timer = Timer.scheduledTimer(withTimeInterval: 60 * 60, repeats: true) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in await self.runIfDue() }
        }
        Task { await runIfDue() }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    func runIfDue() async {
        guard !isRunning else { return }
        guard CloudBackupSchedule.isDue(
            lastBackupAt: lastBackupProvider(),
            intervalHours: intervalHours
        ) else { return }
        isRunning = true
        _ = await backupAction()
        isRunning = false
    }
}
