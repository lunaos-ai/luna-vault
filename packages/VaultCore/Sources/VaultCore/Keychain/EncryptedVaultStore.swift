import CryptoKit
import Foundation

/// Encrypted secret vault on disk; master key in Keychain (not beside ciphertext).
/// Product auth remains `BiometricGate` on every App/CLI read path.
public final class EncryptedVaultStore: VersionedSecretStoring, @unchecked Sendable {
    public static let revisionRetentionPerSecret = 50
    static let legacyMigrationBackupFilename = "secrets.vault.pre-versioning-v1"
    static let schemaV3MigrationBackupFilename = "secrets.vault.pre-schema-v3"

    let fileURL: URL
    let keyURL: URL
    let keyAccount: String
    let queue = DispatchQueue(label: "dev.vibevault.vaultfile")
    var key: SymmetricKey?

    public static func defaultDirectory() -> URL {
        VaultPaths.defaultDirectory()
    }

    public init(directory: URL = EncryptedVaultStore.defaultDirectory()) {
        self.fileURL = directory.appendingPathComponent("secrets.vault")
        self.keyURL = directory.appendingPathComponent("master.key")
        self.keyAccount = KeychainMasterKey.account(forVaultDirectory: directory)
        VaultPaths.includeInBackup(directory)
    }

    public func add(_ secret: Secret) throws {
        try add(secret, revisionAction: .created)
    }

    public func add(_ secret: Secret, revisionAction: SecretRevisionAction) throws {
        try KeychainStore.validateName(secret.name)
        try queue.sync {
            var document = try loadDocument()
            guard document.records[secret.name] == nil else { throw SecretError.duplicate(name: secret.name) }
            document.records[secret.name] = Record(secret)
            appendRevision(secret, action: revisionAction, to: &document)
            try saveDocument(document)
        }
    }

    public func update(_ secret: Secret) throws {
        try update(secret, revisionAction: .updated)
    }

    public func update(_ secret: Secret, revisionAction: SecretRevisionAction) throws {
        try KeychainStore.validateName(secret.name)
        try queue.sync {
            var document = try loadDocument()
            guard document.records[secret.name] != nil else { throw SecretError.notFound(name: secret.name) }
            document.records[secret.name] = Record(secret)
            appendRevision(secret, action: revisionAction, to: &document)
            try saveDocument(document)
        }
    }

    public func read(name: String) throws -> Secret {
        try KeychainStore.validateName(name)
        return try queue.sync {
            let document = try loadDocument()
            guard let rec = document.records[name] else { throw SecretError.notFound(name: name) }
            return rec.asSecret()
        }
    }

    public func delete(name: String) throws {
        try delete(name: name, revisionAction: .deleted)
    }

    public func delete(name: String, revisionAction: SecretRevisionAction) throws {
        try KeychainStore.validateName(name)
        try queue.sync {
            var document = try loadDocument()
            guard let removed = document.records.removeValue(forKey: name) else {
                throw SecretError.notFound(name: name)
            }
            appendRevision(
                removed.asSecret(),
                action: revisionAction,
                isDeleted: true,
                to: &document
            )
            try saveDocument(document)
        }
    }

    public func list() throws -> [Secret] {
        try queue.sync {
            try loadDocument().records.values
                .map { $0.asSecret(maskValue: true, includeTOTP: false) }
                .sorted { $0.name < $1.name }
        }
    }

    public func exists(name: String) throws -> Bool {
        try KeychainStore.validateName(name)
        return try queue.sync { try loadDocument().records[name] != nil }
    }

    public func revisions(for name: String) throws -> [SecretRevision] {
        try KeychainStore.validateName(name)
        return try queue.sync {
            try loadDocument().revisions
                .filter { $0.secret.name == name }
                .sorted { $0.capturedAt > $1.capturedAt }
        }
    }

    public func allRevisions() throws -> [SecretRevision] {
        try queue.sync {
            try loadDocument().revisions.sorted { $0.capturedAt > $1.capturedAt }
        }
    }

    public func mergeRevisions(_ revisions: [SecretRevision]) throws {
        guard !revisions.isEmpty else { return }
        for revision in revisions {
            try KeychainStore.validateName(revision.secret.name)
        }
        try queue.sync {
            var document = try loadDocument()
            var existingIDs = Set(document.revisions.map(\.id))
            document.revisions.append(contentsOf: revisions.filter { existingIDs.insert($0.id).inserted })
            pruneRevisions(in: &document)
            try saveDocument(document)
        }
    }

    public func restoreRevision(id: UUID, restoredAt: Date = Date()) throws -> Secret {
        try queue.sync {
            var document = try loadDocument()
            guard let revision = document.revisions.first(where: { $0.id == id }) else {
                throw SecretError.vaultIO("revision not found: \(id.uuidString)")
            }
            let source = revision.secret
            let restored = Secret(
                name: source.name,
                value: source.value,
                updatedAt: restoredAt,
                createdAt: source.createdAt,
                notes: source.notes,
                expiresAt: source.expiresAt,
                rotateEveryDays: source.rotateEveryDays,
                lastRotatedAt: source.lastRotatedAt,
                mcpAllowed: source.mcpAllowed,
                totpAuthURL: source.totpAuthURL
            )
            document.records[restored.name] = Record(restored)
            appendRevision(restored, action: .restored, to: &document)
            try saveDocument(document)
            return restored
        }
    }

}
