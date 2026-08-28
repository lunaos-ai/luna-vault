import Foundation
#if canImport(Security)
import Security
#endif

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

/// Prefs: Keychain on macOS; mode-0600 JSON on Linux/Windows.
public final class KeychainPrefs: PreferenceStoring, @unchecked Sendable {
    public static let service = "dev.vibevault.prefs"
    private let serviceName: String
    private let accessGroup: String?
    private let queue = DispatchQueue(label: "dev.vibevault.prefs.queue")
    #if !canImport(Security)
    private var memory: [String: Data] = [:]
    private var loaded = false
    #endif

    public init(service: String = KeychainPrefs.service, accessGroup: String? = nil) {
        self.serviceName = service
        self.accessGroup = accessGroup
    }

    public func data(forKey key: String) -> Data? {
        queue.sync {
            #if canImport(Security)
            var q = base(key)
            q[kSecReturnData as String] = true
            q[kSecMatchLimit as String] = kSecMatchLimitOne
            var item: CFTypeRef?
            guard SecItemCopyMatching(q as CFDictionary, &item) == errSecSuccess,
                  let data = item as? Data else { return nil }
            return data
            #else
            loadIfNeeded()
            return memory[key]
            #endif
        }
    }

    public func set(_ data: Data?, forKey key: String) {
        queue.sync {
            #if canImport(Security)
            SecItemDelete(base(key) as CFDictionary)
            guard let data else { return }
            var query = base(key)
            query[kSecValueData as String] = data
            query[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
            SecItemAdd(query as CFDictionary, nil)
            #else
            loadIfNeeded()
            if let data { memory[key] = data } else { memory.removeValue(forKey: key) }
            try? FileSecureStore.savePrefs(memory, directory: VaultPaths.defaultDirectory())
            #endif
        }
    }

    public func removeAll() {
        queue.sync {
            #if canImport(Security)
            let q: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrService as String: serviceName
            ]
            SecItemDelete(q as CFDictionary)
            #else
            memory = [:]
            loaded = true
            try? FileSecureStore.savePrefs([:], directory: VaultPaths.defaultDirectory())
            #endif
        }
    }

    #if canImport(Security)
    private func base(_ key: String) -> [String: Any] {
        var q: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: key
        ]
        if let accessGroup { q[kSecAttrAccessGroup as String] = accessGroup }
        return q
    }
    #else
    private func loadIfNeeded() {
        guard !loaded else { return }
        memory = FileSecureStore.loadPrefs(directory: VaultPaths.defaultDirectory())
        loaded = true
    }
    #endif
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
