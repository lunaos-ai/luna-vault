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

final class InMemoryAuthenticatorStore: AuthenticatorStoring, @unchecked Sendable {
    private var accounts: [UUID: AuthenticatorAccount] = [:]
    func addAuthenticator(_ account: AuthenticatorAccount) throws {
        if accounts[account.id] != nil { throw AuthenticatorError.duplicate(account.id) }
        accounts[account.id] = account
    }
    func updateAuthenticator(_ account: AuthenticatorAccount) throws {
        guard accounts[account.id] != nil else { throw AuthenticatorError.notFound(account.id) }
        accounts[account.id] = account
    }
    func readAuthenticator(id: UUID) throws -> AuthenticatorAccount {
        guard let account = accounts[id] else { throw AuthenticatorError.notFound(id) }
        return account
    }
    func listAuthenticators() throws -> [AuthenticatorAccountMetadata] {
        accounts.values.map(AuthenticatorAccountMetadata.init)
    }
    func allAuthenticators() throws -> [AuthenticatorAccount] { Array(accounts.values) }
    func deleteAuthenticator(id: UUID) throws {
        guard accounts.removeValue(forKey: id) != nil else { throw AuthenticatorError.notFound(id) }
    }
}
