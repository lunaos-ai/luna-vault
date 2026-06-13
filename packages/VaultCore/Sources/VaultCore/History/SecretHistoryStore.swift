import Foundation
import Security

public struct SecretVersion: Equatable, Hashable, Sendable, Codable, Identifiable {
    public let value: String
    public let savedAt: Date
    public var id: Date { savedAt }
    public init(value: String, savedAt: Date = Date()) {
        self.value = value; self.savedAt = savedAt
    }
    public var maskedValue: String {
        Secret(name: "_", value: value).maskedValue
    }
}

public protocol SecretHistoryWriting: Sendable {
    func record(name: String, value: String, at date: Date) throws
    func versions(name: String) throws -> [SecretVersion]
    func clear(name: String) throws
}

public extension SecretHistoryWriting {
    func record(name: String, value: String) throws {
        try record(name: name, value: value, at: Date())
    }
}

/// Prior secret values kept under a dedicated Keychain service so history is as
/// protected as the live secret — never written to the audit DB in plaintext.
/// Newest first, capped to `limit` entries.
public final class SecretHistoryStore: SecretHistoryWriting, @unchecked Sendable {
    public static let service = "dev.vibevault.history"
    private let serviceName: String
    private let limit: Int

    public init(service: String = SecretHistoryStore.service, limit: Int = 10) {
        self.serviceName = service
        self.limit = max(1, limit)
    }

    public func record(name: String, value: String, at date: Date) throws {
        try KeychainStore.validateName(name)
        var list = try versions(name: name)
        if list.first?.value == value { return }  // no-op on unchanged value
        list.insert(SecretVersion(value: value, savedAt: date), at: 0)
        if list.count > limit { list = Array(list.prefix(limit)) }
        try save(name: name, list: list)
    }

    public func versions(name: String) throws -> [SecretVersion] {
        var query = baseQuery(name: name)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        if status == errSecItemNotFound { return [] }
        guard status == errSecSuccess, let data = item as? Data else {
            throw SecretError.keychainStatus(status)
        }
        return (try? JSONDecoder.luna.decode([SecretVersion].self, from: data)) ?? []
    }

    public func clear(name: String) throws {
        let status = SecItemDelete(baseQuery(name: name) as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw SecretError.keychainStatus(status)
        }
    }

    private func save(name: String, list: [SecretVersion]) throws {
        let data = try JSONEncoder.luna.encode(list)
        let base = baseQuery(name: name)
        let update = [kSecValueData as String: data]
        let status = SecItemUpdate(base as CFDictionary, update as CFDictionary)
        if status == errSecSuccess { return }
        if status == errSecItemNotFound {
            var add = base
            add[kSecValueData as String] = data
            let addStatus = SecItemAdd(add as CFDictionary, nil)
            guard addStatus == errSecSuccess else { throw SecretError.keychainStatus(addStatus) }
            return
        }
        throw SecretError.keychainStatus(status)
    }

    private func baseQuery(name: String) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: name
        ]
    }
}

/// In-memory history for tests and non-Keychain hosts.
public final class InMemoryHistoryStore: SecretHistoryWriting, @unchecked Sendable {
    private var map: [String: [SecretVersion]] = [:]
    private let limit: Int
    private let lock = NSLock()
    public init(limit: Int = 10) { self.limit = max(1, limit) }

    public func record(name: String, value: String, at date: Date) throws {
        lock.lock(); defer { lock.unlock() }
        var list = map[name] ?? []
        if list.first?.value == value { return }
        list.insert(SecretVersion(value: value, savedAt: date), at: 0)
        map[name] = Array(list.prefix(limit))
    }
    public func versions(name: String) throws -> [SecretVersion] {
        lock.lock(); defer { lock.unlock() }
        return map[name] ?? []
    }
    public func clear(name: String) throws {
        lock.lock(); defer { lock.unlock() }
        map[name] = nil
    }
}
