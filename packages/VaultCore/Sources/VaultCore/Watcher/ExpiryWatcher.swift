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
public final class AlertDedupe: @unchecked Sendable {
    private let userDefaults: UserDefaults
    private let key: String
    private let queue = DispatchQueue(label: "dev.vibevault.alertdedupe")

    public init(userDefaults: UserDefaults = .standard, key: String = "vibe-vault.delivered-alerts") {
        self.userDefaults = userDefaults
        self.key = key
    }

    public func filterNew(_ alerts: [ExpiryAlert]) -> [ExpiryAlert] {
        queue.sync {
            let delivered = Set(userDefaults.stringArray(forKey: key) ?? [])
            return alerts.filter { !delivered.contains($0.id) }
        }
    }

    public func markDelivered(_ alerts: [ExpiryAlert]) {
        queue.sync {
            var delivered = Set(userDefaults.stringArray(forKey: key) ?? [])
            for alert in alerts { delivered.insert(alert.id) }
            // cap memory: keep last 500 entries
            if delivered.count > 500 {
                let trimmed = Array(delivered).suffix(500)
                userDefaults.set(Array(trimmed), forKey: key)
            } else {
                userDefaults.set(Array(delivered), forKey: key)
            }
        }
    }

    public func reset() {
        queue.sync { userDefaults.removeObject(forKey: key) }
    }
}
