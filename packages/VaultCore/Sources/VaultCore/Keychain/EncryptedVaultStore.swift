import CryptoKit
import Foundation

/// Encrypted secret vault on disk; master key in Keychain (not beside ciphertext).
/// Product auth remains `BiometricGate` on every App/CLI read path.
public final class EncryptedVaultStore: VersionedSecretStoring, @unchecked Sendable {
    public static let revisionRetentionPerSecret = 50
    static let legacyMigrationBackupFilename = "secrets.vault.pre-versioning-v1"

    private let fileURL: URL
    private let keyURL: URL
    private let keyAccount: String
    private let queue = DispatchQueue(label: "dev.vibevault.vaultfile")
    private var key: SymmetricKey?

    public static func defaultDirectory() -> URL {
        VaultPaths.defaultDirectory()
    }

    public init(directory: URL = EncryptedVaultStore.defaultDirectory()) {
        self.fileURL = directory.appendingPathComponent("secrets.vault")
        self.keyURL = directory.appendingPathComponent("master.key")
        let leaf = directory.standardizedFileURL.lastPathComponent
        self.keyAccount = leaf == "vibe-vault"
            ? KeychainMasterKey.defaultAccount
            : "vault.master.\(leaf)"
        VaultPaths.excludeFromBackup(directory)
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

    // MARK: - Persistence

    private func masterKey() throws -> SymmetricKey {
        if let key { return key }
        let loaded = try VaultFileCrypto.loadOrCreateKey(
            legacyFileURL: keyURL, account: keyAccount
        )
        key = loaded
        return loaded
    }

    private func loadDocument() throws -> VaultDocument {
        let fm = FileManager.default
        guard fm.fileExists(atPath: fileURL.path) else { return VaultDocument() }
        let blob = try Data(contentsOf: fileURL)
        let plain = try VaultFileCrypto.open(blob, key: masterKey())
        let dec = JSONDecoder()
        dec.dateDecodingStrategy = .iso8601
        if var document = try? dec.decode(VaultDocument.self, from: plain) {
            if backfillRevisionBaselines(in: &document) {
                try saveDocument(document)
            }
            return document
        }
        let records = try dec.decode([Record].self, from: plain)
        var document = VaultDocument(records: Dictionary(uniqueKeysWithValues: records.map { ($0.name, $0) }))
        _ = backfillRevisionBaselines(in: &document)
        try preserveLegacyVault(blob)
        try saveDocument(document)
        return document
    }

    private func preserveLegacyVault(_ blob: Data) throws {
        let backupURL = fileURL.deletingLastPathComponent()
            .appendingPathComponent(Self.legacyMigrationBackupFilename)
        guard !FileManager.default.fileExists(atPath: backupURL.path) else { return }
        try blob.write(to: backupURL, options: .atomic)
        try FileManager.default.setAttributes(
            [.posixPermissions: 0o600], ofItemAtPath: backupURL.path
        )
        VaultPaths.excludeFromBackup(backupURL)
    }

    private func saveDocument(_ document: VaultDocument) throws {
        let enc = JSONEncoder()
        enc.dateEncodingStrategy = .iso8601
        let plain = try enc.encode(document)
        let blob = try VaultFileCrypto.seal(plain, key: masterKey())
        try blob.write(to: fileURL, options: .atomic)
        try FileManager.default.setAttributes(
            [.posixPermissions: 0o600], ofItemAtPath: fileURL.path
        )
        VaultPaths.excludeFromBackup(fileURL)
    }

    private func appendRevision(
        _ secret: Secret,
        action: SecretRevisionAction,
        isDeleted: Bool = false,
        to document: inout VaultDocument
    ) {
        document.revisions.append(SecretRevision(
            secret: secret,
            action: action,
            isDeleted: isDeleted
        ))
        pruneRevisions(in: &document)
    }

    private func pruneRevisions(in document: inout VaultDocument) {
        let grouped = Dictionary(grouping: document.revisions, by: { $0.secret.name })
        document.revisions = grouped.values.flatMap { revisions in
            revisions
                .sorted { $0.capturedAt > $1.capturedAt }
                .prefix(Self.revisionRetentionPerSecret)
        }
    }

    private func backfillRevisionBaselines(in document: inout VaultDocument) -> Bool {
        let versionedNames = Set(document.revisions.map { $0.secret.name })
        let missing = document.records.values.filter { !versionedNames.contains($0.name) }
        guard !missing.isEmpty else { return false }
        document.revisions.append(contentsOf: missing.map { record in
            let secret = record.asSecret()
            return SecretRevision(
                secret: secret,
                capturedAt: secret.updatedAt,
                action: .baseline
            )
        })
        return true
    }

    private struct VaultDocument: Codable {
        var version = 2
        var records: [String: Record] = [:]
        var revisions: [SecretRevision] = []
    }

    private struct Record: Codable {
        var name: String
        var value: String
        var createdAt: Date?
        var updatedAt: Date
        var notes: String?
        var expiresAt: Date?
        var rotateEveryDays: Int?
        var lastRotatedAt: Date?
        var mcpAllowed: Bool
        var totpAuthURL: String?

        init(_ s: Secret) {
            name = s.name; value = s.value; updatedAt = s.updatedAt
            createdAt = s.createdAt
            notes = s.notes; expiresAt = s.expiresAt
            rotateEveryDays = s.rotateEveryDays; lastRotatedAt = s.lastRotatedAt
            mcpAllowed = s.mcpAllowed
            totpAuthURL = s.totpAuthURL
        }

        func asSecret(maskValue: Bool = false, includeTOTP: Bool = true) -> Secret {
            Secret(
                name: name, value: maskValue ? "" : value, updatedAt: updatedAt, createdAt: createdAt ?? updatedAt,
                notes: notes, expiresAt: expiresAt, rotateEveryDays: rotateEveryDays,
                lastRotatedAt: lastRotatedAt, mcpAllowed: mcpAllowed,
                hasTOTP: totpAuthURL != nil,
                totpAuthURL: includeTOTP ? totpAuthURL : nil
            )
        }
    }
}
