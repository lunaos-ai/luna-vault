import Foundation
import VaultCore

final class InMemoryKeychainStore: KeychainStoring, @unchecked Sendable {
    private var items: [String: Secret] = [:]
    func add(_ secret: Secret) throws {
        if items[secret.name] != nil { throw SecretError.duplicate(name: secret.name) }
        items[secret.name] = secret
    }
    func update(_ secret: Secret) throws {
        guard items[secret.name] != nil else { throw SecretError.notFound(name: secret.name) }
        items[secret.name] = secret
    }
    func read(name: String) throws -> Secret {
        guard let s = items[name] else { throw SecretError.notFound(name: name) }
        return s
    }
    func delete(name: String) throws {
        guard items.removeValue(forKey: name) != nil else { throw SecretError.notFound(name: name) }
    }
    func list() throws -> [Secret] { Array(items.values) }
    func exists(name: String) throws -> Bool { items[name] != nil }
}

final class NullAuditLogger: AuditLogging, @unchecked Sendable {
    func record(_ event: AuditEvent) throws {}
    func query(_ filter: AuditFilter) throws -> [AuditEvent] { [] }
    func purge(olderThan: Date) throws -> Int { 0 }
}
