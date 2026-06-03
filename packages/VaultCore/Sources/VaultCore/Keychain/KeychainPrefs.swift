import Foundation
import Security

public protocol PreferenceStoring: Sendable {
    func data(forKey key: String) -> Data?
    func set(_ data: Data?, forKey key: String)
    func removeAll()
}

public extension PreferenceStoring {
    func setCodable<T: Encodable>(_ value: T?, forKey key: String) {
        guard let value else { set(nil, forKey: key); return }
        if let data = try? JSONEncoder().encode(value) { set(data, forKey: key) }
    }
    func codable<T: Decodable>(_ type: T.Type, forKey key: String) -> T? {
        guard let data = data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }
}

public final class KeychainPrefs: PreferenceStoring, @unchecked Sendable {
    public static let service = "dev.vibevault.prefs"
    private let serviceName: String
    private let accessGroup: String?
    private let queue = DispatchQueue(label: "dev.vibevault.prefs.queue")

    public init(service: String = KeychainPrefs.service, accessGroup: String? = nil) {
        self.serviceName = service
        self.accessGroup = accessGroup
    }

    public func data(forKey key: String) -> Data? {
        queue.sync {
            var q = base(key)
            q[kSecReturnData as String] = true
            q[kSecMatchLimit as String] = kSecMatchLimitOne
            var item: CFTypeRef?
            let status = SecItemCopyMatching(q as CFDictionary, &item)
            guard status == errSecSuccess else { return nil }
            return item as? Data
        }
    }

    public func set(_ data: Data?, forKey key: String) {
        queue.sync {
            let q = base(key)
            guard let data else {
                SecItemDelete(q as CFDictionary)
                return
            }
            var query = q
            query[kSecValueData as String] = data
            let addStatus = SecItemAdd(query as CFDictionary, nil)
            if addStatus == errSecDuplicateItem {
                let update: [String: Any] = [kSecValueData as String: data]
                SecItemUpdate(q as CFDictionary, update as CFDictionary)
            }
        }
    }

    public func removeAll() {
        queue.sync {
            var q: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrService as String: serviceName
            ]
            if let g = accessGroup { q[kSecAttrAccessGroup as String] = g }
            SecItemDelete(q as CFDictionary)
        }
    }

    private func base(_ key: String) -> [String: Any] {
        var q: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: key
        ]
        if let g = accessGroup { q[kSecAttrAccessGroup as String] = g }
        return q
    }
}

public final class InMemoryPrefs: PreferenceStoring, @unchecked Sendable {
    private var store: [String: Data] = [:]
    private let queue = DispatchQueue(label: "dev.vibevault.prefs.memory")
    public init() {}
    public func data(forKey key: String) -> Data? { queue.sync { store[key] } }
    public func set(_ data: Data?, forKey key: String) {
        queue.sync { if let d = data { store[key] = d } else { store.removeValue(forKey: key) } }
    }
    public func removeAll() { queue.sync { store.removeAll() } }
}
