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

    func test_persists_across_instances() throws {
        try store.add(Secret(name: "PERSIST", value: "keep"))
        let again = EncryptedVaultStore(directory: dir)
        XCTAssertEqual(try again.read(name: "PERSIST").value, "keep")
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
        var bytes = [UInt8](repeating: 7, count: 32)
        let legacy = dir.appendingPathComponent("master.key")
        try Data(bytes).write(to: legacy, options: .atomic)
        KeychainMasterKey.deleteForTests(account: keyAccount)
        let migrated = EncryptedVaultStore(directory: dir)
        try migrated.add(Secret(name: "AFTER", value: "ok"))
        XCTAssertFalse(FileManager.default.fileExists(atPath: legacy.path))
        XCTAssertEqual(try migrated.read(name: "AFTER").value, "ok")
    }
}
