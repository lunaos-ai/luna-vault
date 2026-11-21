import AppKit
import Combine
import Foundation
import VaultCore

/// Fires (debounced) when the vault file may have changed outside this window:
/// a CLI/MCP write announced via the distributed notification, or the app
/// becoming active again as a fallback. Selection is held by secret id in the
/// views, so a reload does not disturb an in-progress selection.
@MainActor
enum VaultChangeSignal {
    static var publisher: AnyPublisher<Void, Never> {
        let external = DistributedNotificationCenter.default()
            .publisher(for: Notification.Name(VaultChangeNotifier.notificationName))
        let active = NotificationCenter.default
            .publisher(for: NSApplication.didBecomeActiveNotification)
        return external.merge(with: active)
            .debounce(for: .milliseconds(300), scheduler: DispatchQueue.main)
            .map { _ in () }
            .eraseToAnyPublisher()
    }
}
