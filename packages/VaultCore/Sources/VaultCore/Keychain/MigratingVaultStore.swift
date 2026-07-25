import Foundation

/// File vault first; legacy Keychain is copied in once, then never read again for that name.
public final class MigratingVaultStore: VersionedSecretStoring, @unchecked Sendable {
    private let primary: EncryptedVaultStore
    private let legacy: KeychainStore
    private let queue = DispatchQueue(label: "dev.vibevault.migrate")

    public init(
        primary: EncryptedVaultStore = EncryptedVaultStore(),
        legacy: KeychainStore = KeychainStore()
    ) {
        self.primary = primary
        self.legacy = legacy
    }

    public func add(_ secret: Secret) throws { try primary.add(secret) }

    public func add(_ secret: Secret, revisionAction: SecretRevisionAction) throws {
        try primary.add(secret, revisionAction: revisionAction)
    }

    public func update(_ secret: Secret) throws {
        try upsertPrimary(secret)
        // Never block on Keychain delete — it re-prompts and is optional cleanup.
    }

    public func update(_ secret: Secret, revisionAction: SecretRevisionAction) throws {
        if try primary.exists(name: secret.name) {
            try primary.update(secret, revisionAction: revisionAction)
        } else {
            try primary.add(secret, revisionAction: revisionAction)
        }
    }

    public func read(name: String) throws -> Secret {
        try queue.sync {
            if try primary.exists(name: name) {
                return try primary.read(name: name)
            }
            let secret = try legacy.read(name: name)
            try upsertPrimary(secret)
            try? legacy.delete(name: name)
            return try primary.read(name: name)
        }
    }

    public func delete(name: String) throws {
        try delete(name: name, revisionAction: .deleted)
    }

    public func delete(name: String, revisionAction: SecretRevisionAction) throws {
        var deleted = false
        do {
            try primary.delete(name: name, revisionAction: revisionAction)
            deleted = true
        } catch SecretError.notFound {}
        do { try legacy.delete(name: name); deleted = true } catch SecretError.notFound {}
        if !deleted { throw SecretError.notFound(name: name) }
    }

    public func list() throws -> [Secret] {
        try queue.sync { try primary.list() }
    }

    public func exists(name: String) throws -> Bool {
        try primary.exists(name: name)
    }

    public func revisions(for name: String) throws -> [SecretRevision] {
        try primary.revisions(for: name)
    }

    public func allRevisions() throws -> [SecretRevision] {
        try primary.allRevisions()
    }

    public func mergeRevisions(_ revisions: [SecretRevision]) throws {
        try primary.mergeRevisions(revisions)
    }

    public func restoreRevision(id: UUID, restoredAt: Date = Date()) throws -> Secret {
        try primary.restoreRevision(id: id, restoredAt: restoredAt)
    }

    /// How many Keychain items are not yet in the file vault.
    public func pendingLegacyCount() -> Int {
        let legacyNames = Set((try? legacy.list().map(\.name)) ?? [])
        let primaryNames = Set((try? primary.list().map(\.name)) ?? [])
        return legacyNames.subtracting(primaryNames).count
    }

    /// Pull every legacy Keychain secret into the file vault, then delete the Keychain copy.
    @discardableResult
    public func migrateAllFromKeychain() -> (ok: Int, failed: [String]) {
        let names = (try? legacy.list().map(\.name)) ?? []
        var ok = 0
        var failed: [String] = []
        for name in names {
            do {
                if (try? primary.exists(name: name)) != true {
                    let secret = try legacy.read(name: name)
                    try upsertPrimary(secret)
                }
                try? legacy.delete(name: name)
                ok += 1
            } catch {
                failed.append(name)
            }
        }
        return (ok, failed)
    }

    private func upsertPrimary(_ secret: Secret) throws {
        if try primary.exists(name: secret.name) {
            try primary.update(secret)
        } else {
            try primary.add(secret)
        }
        guard try primary.exists(name: secret.name) else {
            throw SecretError.vaultIO("failed to persist \(secret.name)")
        }
    }
}
