import Foundation

public struct ExpiryAlert: Equatable, Sendable, Identifiable {
    public enum Kind: String, Sendable {
        case expired, expiringSoon, rotationDue
    }
    public let secretName: String
    public let kind: Kind
    public let dueDate: Date?
    public var id: String { "\(secretName)-\(kind.rawValue)" }

    public var title: String {
        switch kind {
        case .expired: return "Secret expired"
        case .expiringSoon: return "Secret expires soon"
        case .rotationDue: return "Secret rotation due"
        }
    }

    public var body: String {
        switch kind {
        case .expired:
            return "\(secretName) is past its expiry date. Rotate or update it."
        case .expiringSoon:
            if let due = dueDate {
                let days = Calendar.current.dateComponents([.day], from: Date(), to: due).day ?? 0
                return "\(secretName) expires in \(days) day\(days == 1 ? "" : "s")."
            }
            return "\(secretName) is about to expire."
        case .rotationDue:
            return "\(secretName) is due for rotation. Run `vibevault rotate \(secretName)`."
        }
    }
}

public protocol ExpiryWatching: Sendable {
    func scan(secrets: [Secret], warnWithinDays: Int, now: Date) -> [ExpiryAlert]
}

public final class ExpiryWatcher: ExpiryWatching, @unchecked Sendable {
    public init() {}

    public func scan(secrets: [Secret], warnWithinDays: Int = 14, now: Date = Date()) -> [ExpiryAlert] {
        var out: [ExpiryAlert] = []
        for secret in secrets {
            if let exp = secret.expiresAt {
                if now >= exp {
                    out.append(ExpiryAlert(secretName: secret.name, kind: .expired, dueDate: exp))
                } else {
                    let days = Calendar.current.dateComponents([.day], from: now, to: exp).day ?? Int.max
                    if days <= warnWithinDays {
                        out.append(ExpiryAlert(secretName: secret.name, kind: .expiringSoon, dueDate: exp))
                    }
                }
            }
            if secret.isRotationDue {
                out.append(ExpiryAlert(secretName: secret.name, kind: .rotationDue, dueDate: secret.rotationDueAt))
            }
        }
        return out
    }
}

/// Tracks which alerts have been delivered so we don't re-notify on each scan.
/// Persists into Keychain via PreferenceStoring (no UserDefaults).
public final class AlertDedupe: @unchecked Sendable {
    private let prefs: PreferenceStoring
    private let key: String
    private let queue = DispatchQueue(label: "dev.vibevault.alertdedupe")

    public init(prefs: PreferenceStoring = KeychainPrefs(), key: String = "delivered-alerts") {
        self.prefs = prefs
        self.key = key
    }

    public func filterNew(_ alerts: [ExpiryAlert]) -> [ExpiryAlert] {
        queue.sync {
            let delivered = Set(load())
            return alerts.filter { !delivered.contains($0.id) }
        }
    }

    public func markDelivered(_ alerts: [ExpiryAlert]) {
        queue.sync {
            var delivered = Set(load())
            for alert in alerts { delivered.insert(alert.id) }
            let arr = delivered.count > 500 ? Array(Array(delivered).suffix(500)) : Array(delivered)
            prefs.setCodable(arr, forKey: key)
        }
    }

    public func reset() {
        queue.sync { prefs.set(nil, forKey: key) }
    }

    private func load() -> [String] {
        prefs.codable([String].self, forKey: key) ?? []
    }
}
