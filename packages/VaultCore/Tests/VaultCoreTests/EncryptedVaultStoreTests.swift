import CryptoKit
import XCTest
@testable import VaultCore

final class EncryptedVaultStoreTests: XCTestCase {
    private var dir: URL!
    private var store: EncryptedVaultStore!
    private var keyAccount: String!

    override func setUpWithError() throws {
        dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("vv-vault-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        keyAccount = "vault.master.\(dir.lastPathComponent)"
        store = EncryptedVaultStore(directory: dir)
    }

    override func tearDownWithError() throws {
        KeychainMasterKey.deleteForTests(account: keyAccount)
        try? FileManager.default.removeItem(at: dir)
    }

    func test_add_read_roundTrip() throws {
        try store.add(Secret(name: "API_KEY", value: "secret-value"))
        let read = try store.read(name: "API_KEY")
        XCTAssertEqual(read.value, "secret-value")
    }

    func test_list_masks_values() throws {
        try store.add(Secret(name: "A", value: "aaa"))
        let listed = try store.list()
        XCTAssertEqual(listed.count, 1)
        XCTAssertEqual(listed[0].value, "")
    }

    func test_update_and_delete() throws {
        try store.add(Secret(name: "X", value: "v1"))
        try store.update(Secret(name: "X", value: "v2"))
        XCTAssertEqual(try store.read(name: "X").value, "v2")
        try store.delete(name: "X")
        XCTAssertThrowsError(try store.read(name: "X"))
    }

    func test_revision_history_records_changes_and_restores_one_version() throws {
        let createdAt = Date(timeIntervalSince1970: 1_800_000_000)
        let updatedAt = createdAt.addingTimeInterval(60)
        try store.add(Secret(name: "X", value: "v1", updatedAt: createdAt))
        try store.update(
            Secret(name: "X", value: "v2", updatedAt: updatedAt),
            revisionAction: .rotated
        )
        try store.delete(name: "X", revisionAction: .deleted)

        let history = try store.revisions(for: "X")
        XCTAssertEqual(history.map(\.action), [.deleted, .rotated, .created])
        XCTAssertTrue(history[0].isDeleted)
        XCTAssertEqual(history[2].secret.value, "v1")

        let restored = try store.restoreRevision(id: history[2].id, restoredAt: updatedAt.addingTimeInterval(60))
        XCTAssertEqual(restored.value, "v1")
        XCTAssertEqual(try store.read(name: "X").value, "v1")
        XCTAssertEqual(try store.revisions(for: "X").first?.action, .restored)
    }

    func test_revision_history_is_bounded_per_secret() throws {
        try store.add(Secret(name: "BOUNDED", value: "v0"))
        for index in 1...55 {
            try store.update(Secret(name: "BOUNDED", value: "v\(index)"))
        }

        let history = try store.revisions(for: "BOUNDED")
        XCTAssertEqual(history.count, EncryptedVaultStore.revisionRetentionPerSecret)
        XCTAssertEqual(history.first?.secret.value, "v55")
    }

    func test_revision_merge_deduplicates_ids() throws {
        let timestamp = Date(timeIntervalSince1970: 1_800_000_000)
        let revision = SecretRevision(
            secret: Secret(name: "MERGED", value: "remote", updatedAt: timestamp),
            capturedAt: timestamp,
            action: .synced,
            sourceHost: "mac-b"
        )
        try store.mergeRevisions([revision, revision])
        try store.mergeRevisions([revision])

        XCTAssertEqual(try store.revisions(for: "MERGED"), [revision])
    }

    func test_persists_across_instances() throws {
        try store.add(Secret(name: "PERSIST", value: "keep"))
        let again = EncryptedVaultStore(directory: dir)
        XCTAssertEqual(try again.read(name: "PERSIST").value, "keep")
    }

    func test_totp_is_preserved_but_not_exposed_by_list() throws {
        let authURL = "otpauth://totp/App:me@example.com?secret=JBSWY3DPEHPK3PXP&issuer=App"
        try store.add(Secret(name: "APP_PASSWORD", value: "secret-value", totpAuthURL: authURL))

        let listed = try store.list()
        XCTAssertEqual(listed.first?.hasTOTP, true)
        XCTAssertNil(listed.first?.totpAuthURL)
        XCTAssertEqual(try store.read(name: "APP_PASSWORD").totpAuthURL, authURL)
    }

    func test_tampered_blob_fails_closed() throws {
        try store.add(Secret(name: "T", value: "v"))
        let vault = dir.appendingPathComponent("secrets.vault")
        var blob = try Data(contentsOf: vault)
        blob[blob.count / 2] ^= 0xFF
        try blob.write(to: vault, options: .atomic)
        let again = EncryptedVaultStore(directory: dir)
        XCTAssertThrowsError(try again.read(name: "T"))
    }

    func test_migrates_legacy_master_key_file() throws {
        let bytes = [UInt8](repeating: 7, count: 32)
        let legacy = dir.appendingPathComponent("master.key")
        try Data(bytes).write(to: legacy, options: .atomic)
        KeychainMasterKey.deleteForTests(account: keyAccount)
        let migrated = EncryptedVaultStore(directory: dir)
        try migrated.add(Secret(name: "AFTER", value: "ok"))
        XCTAssertFalse(FileManager.default.fileExists(atPath: legacy.path))
        XCTAssertEqual(try migrated.read(name: "AFTER").value, "ok")
    }

    func test_migrates_legacy_vault_with_encrypted_rollback_copy() throws {
        let keyBytes = Data(repeating: 9, count: 32)
        let legacyKeyURL = dir.appendingPathComponent("master.key")
        try keyBytes.write(to: legacyKeyURL, options: .atomic)
        KeychainMasterKey.deleteForTests(account: keyAccount)

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let legacyPlaintext = try encoder.encode([
            LegacyRecord(
                name: "LEGACY_KEY",
                value: "legacy-value",
                updatedAt: Date(timeIntervalSince1970: 1_700_000_000),
                mcpAllowed: false
            )
        ])
        let originalBlob = try VaultFileCrypto.seal(
            legacyPlaintext,
            key: SymmetricKey(data: keyBytes)
        )
        try originalBlob.write(to: dir.appendingPathComponent("secrets.vault"), options: .atomic)

        let migrated = EncryptedVaultStore(directory: dir)
        XCTAssertEqual(try migrated.read(name: "LEGACY_KEY").value, "legacy-value")
        XCTAssertEqual(try migrated.revisions(for: "LEGACY_KEY").first?.action, .baseline)

        let backupURL = dir.appendingPathComponent(EncryptedVaultStore.legacyMigrationBackupFilename)
        XCTAssertEqual(try Data(contentsOf: backupURL), originalBlob)
        let permissions = try FileManager.default.attributesOfItem(atPath: backupURL.path)[.posixPermissions] as? NSNumber
        XCTAssertEqual(permissions?.intValue, 0o600)
    }

    private struct LegacyRecord: Codable {
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
    }
}
