import CryptoKit
import Foundation

/// Encrypted secret vault on disk; master key in Keychain (not beside ciphertext).
/// Product auth remains `BiometricGate` on every App/CLI read path.
public final class EncryptedVaultStore: KeychainStoring, @unchecked Sendable {
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
        try KeychainStore.validateName(secret.name)
        try queue.sync {
            var all = try loadAll()
            guard all[secret.name] == nil else { throw SecretError.duplicate(name: secret.name) }
            all[secret.name] = Record(secret)
            try saveAll(all)
        }
    }

    public func update(_ secret: Secret) throws {
        try KeychainStore.validateName(secret.name)
        try queue.sync {
            var all = try loadAll()
            guard all[secret.name] != nil else { throw SecretError.notFound(name: secret.name) }
            all[secret.name] = Record(secret)
            try saveAll(all)
        }
    }

    public func read(name: String) throws -> Secret {
        try KeychainStore.validateName(name)
        return try queue.sync {
            let all = try loadAll()
            guard let rec = all[name] else { throw SecretError.notFound(name: name) }
            return rec.asSecret()
        }
    }

    public func delete(name: String) throws {
        try KeychainStore.validateName(name)
        try queue.sync {
            var all = try loadAll()
            guard all.removeValue(forKey: name) != nil else {
                throw SecretError.notFound(name: name)
            }
            try saveAll(all)
        }
    }

    public func list() throws -> [Secret] {
        try queue.sync {
            try loadAll().values.map { $0.asSecret(maskValue: true) }.sorted { $0.name < $1.name }
        }
    }

    public func exists(name: String) throws -> Bool {
        try KeychainStore.validateName(name)
        return try queue.sync { try loadAll()[name] != nil }
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

    private func loadAll() throws -> [String: Record] {
        let fm = FileManager.default
        guard fm.fileExists(atPath: fileURL.path) else { return [:] }
        let blob = try Data(contentsOf: fileURL)
        let plain = try VaultFileCrypto.open(blob, key: masterKey())
        let dec = JSONDecoder()
        dec.dateDecodingStrategy = .iso8601
        let records = try dec.decode([Record].self, from: plain)
        return Dictionary(uniqueKeysWithValues: records.map { ($0.name, $0) })
    }

    private func saveAll(_ all: [String: Record]) throws {
        let records = all.values.sorted { $0.name < $1.name }
        let enc = JSONEncoder()
        enc.dateEncodingStrategy = .iso8601
        let plain = try enc.encode(records)
        let blob = try VaultFileCrypto.seal(plain, key: masterKey())
        try blob.write(to: fileURL, options: .atomic)
        try FileManager.default.setAttributes(
            [.posixPermissions: 0o600], ofItemAtPath: fileURL.path
        )
        VaultPaths.excludeFromBackup(fileURL)
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

        init(_ s: Secret) {
            name = s.name; value = s.value; updatedAt = s.updatedAt
            createdAt = s.createdAt
            notes = s.notes; expiresAt = s.expiresAt
            rotateEveryDays = s.rotateEveryDays; lastRotatedAt = s.lastRotatedAt
            mcpAllowed = s.mcpAllowed
        }

        func asSecret(maskValue: Bool = false) -> Secret {
            Secret(
                name: name, value: maskValue ? "" : value, updatedAt: updatedAt, createdAt: createdAt ?? updatedAt,
                notes: notes, expiresAt: expiresAt, rotateEveryDays: rotateEveryDays,
                lastRotatedAt: lastRotatedAt, mcpAllowed: mcpAllowed
            )
        }
    }
}
