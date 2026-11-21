import Foundation

/// Announces, across processes, that `secrets.vault` was rewritten so a running
/// app can reload. The payload is intentionally empty: no names, no values.
public enum VaultChangeNotifier {
    public static let notificationName = "dev.vibevault.vault-changed"

    static func post() {
        #if os(macOS)
        DistributedNotificationCenter.default().postNotificationName(
            Notification.Name(notificationName), object: nil, userInfo: nil,
            deliverImmediately: true
        )
        #endif
    }
}
