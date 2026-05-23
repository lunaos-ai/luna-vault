import Foundation
import UserNotifications
import VaultCore

@MainActor
final class AppNotifications {
    private let center = UNUserNotificationCenter.current()
    private var authorized = false

    func requestAuthorization() async -> Bool {
        do {
            authorized = try await center.requestAuthorization(options: [.alert, .sound])
            return authorized
        } catch {
            authorized = false
            return false
        }
    }

    func currentAuthStatus() async -> UNAuthorizationStatus {
        await withCheckedContinuation { cont in
            center.getNotificationSettings { settings in
                cont.resume(returning: settings.authorizationStatus)
            }
        }
    }

    func deliver(_ alerts: [ExpiryAlert]) async {
        guard !alerts.isEmpty else { return }
        if !authorized {
            let status = await currentAuthStatus()
            switch status {
            case .authorized, .provisional, .ephemeral:
                authorized = true
            case .notDetermined:
                authorized = await requestAuthorization()
            default:
                return
            }
        }
        for alert in alerts {
            let content = UNMutableNotificationContent()
            content.title = alert.title
            content.body = alert.body
            content.sound = .default
            content.userInfo = ["secret": alert.secretName, "kind": alert.kind.rawValue]
            let request = UNNotificationRequest(
                identifier: alert.id,
                content: content,
                trigger: nil
            )
            try? await center.add(request)
        }
    }
}
