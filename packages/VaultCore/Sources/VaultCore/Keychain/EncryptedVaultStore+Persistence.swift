import CryptoKit
import Foundation

extension EncryptedVaultStore {
    func masterKey() throws -> SymmetricKey {
        if let cachedKey = key { return cachedKey }
        let allowCreate = !FileManager.default.fileExists(atPath: fileURL.path)
        let loaded = try VaultFileCrypto.loadOrCreateKey(
            legacyFileURL: keyURL,
            account: keyAccount,
            allowCreate: allowCreate
        )
        key = loaded
        return loaded
    }

    func loadDocument() throws -> VaultDocument {
        let fm = FileManager.default
        guard fm.fileExists(atPath: fileURL.path) else { return VaultDocument() }
        let blob = try Data(contentsOf: fileURL)
        let vaultKey = try masterKey()
        let plain: Data
        do {
            plain = try VaultFileCrypto.open(blob, key: vaultKey)
        } catch {
            throw LocalVaultRecoveryError.masterKeyUnavailable
        }
        let dec = JSONDecoder()
        dec.dateDecodingStrategy = .iso8601
        if var document = try? dec.decode(VaultDocument.self, from: plain) {
            guard document.version <= 3 else {
                throw SecretError.vaultIO("vault schema \(document.version) requires a newer Vibe Vault")
            }
            let requiresMigration = document.version < 3
            document.version = 3
            let addedBaselines = backfillRevisionBaselines(in: &document)
            if requiresMigration {
                try preserveVault(blob, filename: Self.schemaV3MigrationBackupFilename)
            }
            if requiresMigration || addedBaselines {
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
        try preserveVault(blob, filename: Self.legacyMigrationBackupFilename)
    }

    private func preserveVault(_ blob: Data, filename: String) throws {
        let backupURL = fileURL.deletingLastPathComponent()
            .appendingPathComponent(filename)
        guard !FileManager.default.fileExists(atPath: backupURL.path) else { return }
        try blob.write(to: backupURL, options: .atomic)
        try FileManager.default.setAttributes(
            [.posixPermissions: 0o600], ofItemAtPath: backupURL.path
        )
        VaultPaths.includeInBackup(backupURL)
    }

    func saveDocument(_ document: VaultDocument) throws {
        let enc = JSONEncoder()
        enc.dateEncodingStrategy = .iso8601
        let plain = try enc.encode(document)
        let blob = try VaultFileCrypto.seal(plain, key: masterKey())
        try blob.write(to: fileURL, options: .atomic)
        try FileManager.default.setAttributes(
            [.posixPermissions: 0o600], ofItemAtPath: fileURL.path
        )
        VaultPaths.includeInBackup(fileURL)
    }

    func appendRevision(
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

    func pruneRevisions(in document: inout VaultDocument) {
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

    struct VaultDocument: Codable {
        var version = 3
        var records: [String: Record] = [:]
        var revisions: [SecretRevision] = []
        var authenticatorAccounts: [UUID: AuthenticatorAccount] = [:]
        var authenticatorRevisions: [AuthenticatorRevision] = []

        enum CodingKeys: String, CodingKey {
            case version, records, revisions, authenticatorAccounts, authenticatorRevisions
        }

        init(records: [String: Record] = [:]) {
            self.records = records
        }

        init(from decoder: Decoder) throws {
            let values = try decoder.container(keyedBy: CodingKeys.self)
            version = try values.decodeIfPresent(Int.self, forKey: .version) ?? 2
            records = try values.decodeIfPresent([String: Record].self, forKey: .records) ?? [:]
            revisions = try values.decodeIfPresent([SecretRevision].self, forKey: .revisions) ?? []
            authenticatorAccounts = try values.decodeIfPresent(
                [UUID: AuthenticatorAccount].self, forKey: .authenticatorAccounts
            ) ?? [:]
            authenticatorRevisions = try values.decodeIfPresent(
                [AuthenticatorRevision].self, forKey: .authenticatorRevisions
            ) ?? []
        }
    }

    struct Record: Codable {
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
