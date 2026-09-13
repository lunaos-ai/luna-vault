import XCTest
@testable import VaultCore

final class LinuxMasterKeyStoreTests: XCTestCase {
    private var directory: URL!

    override func setUpWithError() throws {
        directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("vv-linux-key-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: directory)
    }

    func test_hex_roundTrip() throws {
        let data = Data((0..<32).map { UInt8($0) })
        let hex = LinuxMasterKeyHex.encode(data)
        XCTAssertEqual(hex.count, 64)
        XCTAssertEqual(try LinuxMasterKeyHex.decode(hex), data)
        XCTAssertEqual(try LinuxMasterKeyHex.decode(hex.uppercased()), data)
    }

    func test_hex_rejects_corrupt_input() {
        XCTAssertThrowsError(try LinuxMasterKeyHex.decode("abc"))
        XCTAssertThrowsError(try LinuxMasterKeyHex.decode("zz"))
        XCTAssertThrowsError(try LinuxMasterKeyHex.decode(""))
    }

    func test_file_fallback_when_secret_service_unavailable() throws {
        let client = UnavailableSecretServiceClient()
        let key = try PlatformRandom.symmetricKey()
        try LinuxMasterKeyStore.storeMasterKey(
            key, account: "vault.master.test", directory: directory, client: client
        )
        XCTAssertTrue(FileSecureStore.masterKeyExists(account: "vault.master.test", directory: directory))
        let loaded = try LinuxMasterKeyStore.loadMasterKey(
            account: "vault.master.test", directory: directory, client: client
        )
        XCTAssertEqual(loaded, key)
    }

    func test_secret_service_store_does_not_leave_file() throws {
        let client = MemorySecretServiceClient()
        let key = try PlatformRandom.symmetricKey()
        try LinuxMasterKeyStore.storeMasterKey(
            key, account: "vault.master.ring", directory: directory, client: client
        )
        XCTAssertFalse(FileSecureStore.masterKeyExists(account: "vault.master.ring", directory: directory))
        XCTAssertTrue(LinuxMasterKeyStore.masterKeyExists(
            account: "vault.master.ring", directory: directory, client: client
        ))
        let loaded = try LinuxMasterKeyStore.loadMasterKey(
            account: "vault.master.ring", directory: directory, client: client
        )
        XCTAssertEqual(loaded, key)
    }

    func test_migrates_file_key_into_secret_service() throws {
        let client = MemorySecretServiceClient()
        let key = try PlatformRandom.symmetricKey()
        try FileSecureStore.storeMasterKey(key, account: "vault.master.migrate", directory: directory)
        let loaded = try LinuxMasterKeyStore.loadMasterKey(
            account: "vault.master.migrate", directory: directory, client: client
        )
        XCTAssertEqual(loaded, key)
        XCTAssertFalse(FileSecureStore.masterKeyExists(account: "vault.master.migrate", directory: directory))
        XCTAssertEqual(
            try client.lookup(account: "vault.master.migrate"),
            key.withUnsafeBytes { Data($0) }
        )
    }

    func test_delete_clears_file_and_secret_service() throws {
        let client = MemorySecretServiceClient()
        let key = try PlatformRandom.symmetricKey()
        try LinuxMasterKeyStore.storeMasterKey(
            key, account: "vault.master.gone", directory: directory, client: client
        )
        try FileSecureStore.storeMasterKey(key, account: "vault.master.gone", directory: directory)
        LinuxMasterKeyStore.deleteMasterKey(
            account: "vault.master.gone", directory: directory, client: client
        )
        XCTAssertFalse(LinuxMasterKeyStore.masterKeyExists(
            account: "vault.master.gone", directory: directory, client: client
        ))
        XCTAssertNil(try client.lookup(account: "vault.master.gone"))
    }

    func test_rejects_wrong_length_secret_service_payload() throws {
        let client = MemorySecretServiceClient()
        try client.store(account: "vault.master.short", key: Data(repeating: 1, count: 16))
        XCTAssertThrowsError(
            try LinuxMasterKeyStore.loadMasterKey(
                account: "vault.master.short", directory: directory, client: client
            )
        )
    }
}
