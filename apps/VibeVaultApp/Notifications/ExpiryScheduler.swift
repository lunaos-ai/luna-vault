import Foundation
import SwiftUI
import VaultCore

@MainActor
final class ExpiryScheduler: ObservableObject {
    @Published var lastRunAt: Date?
    @Published var lastAlertCount: Int = 0

    private let watcher: ExpiryWatching
    private let dedupe: AlertDedupe
    private let notifier: AppNotifications
    private let secretsProvider: () -> [Secret]
    private var timer: Timer?

    init(
        watcher: ExpiryWatching = ExpiryWatcher(),
        dedupe: AlertDedupe = AlertDedupe(),
        notifier: AppNotifications? = nil,
        secretsProvider: @escaping () -> [Secret]
    ) {
        self.watcher = watcher
        self.dedupe = dedupe
        self.notifier = notifier ?? AppNotifications()
        self.secretsProvider = secretsProvider
    }

    func start(intervalMinutes: Double, warnWithinDays: Int) {
        stop()
        Task { _ = await notifier.requestAuthorization() }
        let interval = max(60, intervalMinutes * 60)
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            Task { @MainActor in await self?.runOnce(warnWithinDays: warnWithinDays) }
        }
        Task { await runOnce(warnWithinDays: warnWithinDays) }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    func runOnce(warnWithinDays: Int) async {
        let alerts = watcher.scan(secrets: secretsProvider(), warnWithinDays: warnWithinDays, now: Date())
        let fresh = dedupe.filterNew(alerts)
        if !fresh.isEmpty {
            await notifier.deliver(fresh)
            dedupe.markDelivered(fresh)
        }
        lastRunAt = Date()
        lastAlertCount = alerts.count
    }

    func resetDedupe() {
        dedupe.reset()
    }
}
