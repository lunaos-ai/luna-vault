import Foundation
import Security

public protocol KeychainStoring: Sendable {
    func add(_ secret: Secret) throws
    func update(_ secret: Secret) throws
    func read(name: String) throws -> Secret
    func delete(name: String) throws
    func list() throws -> [Secret]
    func exists(name: String) throws -> Bool
}

public final class KeychainStore: KeychainStoring, @unchecked Sendable {
    public static let service = "dev.vibevault"
    public static let sharedAccessGroup = "group.dev.vibevault"
    /// Marks items rewritten with an open ACL (no login-password sheet).
    static let openACLLabel = "vv.open-acl"

    private let serviceName: String
    private let accessGroup: String?

    public init(service: String = KeychainStore.service, accessGroup: String? = nil) {
        self.serviceName = service
        self.accessGroup = accessGroup
    }

    public func add(_ secret: Secret) throws {
        try Self.validateName(secret.name)
        var query = baseQuery(name: secret.name)
        query[kSecValueData as String] = Data(secret.value.utf8)
        query[kSecAttrModificationDate as String] = secret.updatedAt
        query[kSecAttrLabel as String] = Self.openACLLabel
        if let encoded = Self.encodeMetadata(from: secret) {
            query[kSecAttrComment as String] = encoded
        }
        KeychainAccess.applyOpenAccess(&query)
        let status = SecItemAdd(query as CFDictionary, nil)
        if status == errSecDuplicateItem { throw SecretError.duplicate(name: secret.name) }
        guard status == errSecSuccess else { throw SecretError.keychainStatus(status) }
    }

    public func update(_ secret: Secret) throws {
        try Self.validateName(secret.name)
        // Rewrite so ACL + label stay open (SecItemUpdate of ACL prompts).
        _ = SecItemDelete(baseQuery(name: secret.name) as CFDictionary)
        try add(secret)
    }

    public func read(name: String) throws -> Secret {
        try Self.validateName(name)
        var query = baseQuery(name: name)
        query[kSecReturnData as String] = true
        query[kSecReturnAttributes as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        if status == errSecItemNotFound { throw SecretError.notFound(name: name) }
        guard status == errSecSuccess, let dict = item as? [String: Any],
              let data = dict[kSecValueData as String] as? Data,
              let value = String(data: data, encoding: .utf8)
        else { throw SecretError.keychainStatus(status) }
        let secret = secretFrom(name: name, value: value, attrs: dict)
        // After the user already authorized this decrypt, heal ACL once so later
        // reveals only hit Touch ID (BiometricGate), never the login-password sheet.
        if (dict[kSecAttrLabel as String] as? String) != Self.openACLLabel {
            try? update(secret)
        }
        return secret
    }

    static func encodeMetadata(from secret: Secret) -> String? {
        let meta = SecretMetadata(
            notes: secret.notes,
            createdAt: secret.createdAt,
            expiresAt: secret.expiresAt,
            rotateEveryDays: secret.rotateEveryDays,
            lastRotatedAt: secret.lastRotatedAt,
            mcpAllowed: secret.mcpAllowed ? true : nil,
            totpAuthURL: secret.totpAuthURL
        )
        return meta.encode()
    }

    public func delete(name: String) throws {
        try Self.validateName(name)
        let status = SecItemDelete(baseQuery(name: name) as CFDictionary)
        if status == errSecItemNotFound { throw SecretError.notFound(name: name) }
        guard status == errSecSuccess else { throw SecretError.keychainStatus(status) }
    }

    public func list() throws -> [Secret] {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecMatchLimit as String: kSecMatchLimitAll,
            kSecReturnAttributes as String: true
        ]
        if let group = accessGroup { query[kSecAttrAccessGroup as String] = group }
        var items: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &items)
        if status == errSecItemNotFound { return [] }
        guard status == errSecSuccess, let array = items as? [[String: Any]] else {
            throw SecretError.keychainStatus(status)
        }
        return array.compactMap { dict in
            guard let name = dict[kSecAttrAccount as String] as? String else { return nil }
            return secretFrom(name: name, value: "", attrs: dict, includeTOTP: false)
        }
    }

    public func exists(name: String) throws -> Bool {
        try Self.validateName(name)
        var query = baseQuery(name: name)
        query[kSecReturnAttributes as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        if status == errSecItemNotFound { return false }
        guard status == errSecSuccess else { throw SecretError.keychainStatus(status) }
        return true
    }

    private func secretFrom(name: String, value: String, attrs: [String: Any], includeTOTP: Bool = true) -> Secret {
        let updatedAt = attrs[kSecAttrModificationDate as String] as? Date ?? Date()
        let meta = SecretMetadata.decode(attrs[kSecAttrComment as String] as? String)
        return Secret(
            name: name, value: value, updatedAt: updatedAt, createdAt: meta.createdAt ?? updatedAt,
            notes: meta.notes, expiresAt: meta.expiresAt,
            rotateEveryDays: meta.rotateEveryDays, lastRotatedAt: meta.lastRotatedAt,
            mcpAllowed: meta.mcpAllowed ?? false,
            hasTOTP: meta.totpAuthURL != nil,
            totpAuthURL: includeTOTP ? meta.totpAuthURL : nil
        )
    }

    private func baseQuery(name: String) -> [String: Any] {
        var q: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: name
        ]
        if let group = accessGroup { q[kSecAttrAccessGroup as String] = group }
        return q
    }

    static func validateName(_ name: String) throws {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed == name, name.count <= 256 else {
            throw SecretError.invalidName(name)
        }
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "_-."))
        guard name.unicodeScalars.allSatisfy({ allowed.contains($0) }) else {
            throw SecretError.invalidName(name)
        }
    }
}
