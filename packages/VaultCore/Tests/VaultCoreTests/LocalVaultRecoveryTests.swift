import XCTest
@testable import VaultCore

final class LocalVaultRecoveryTests: XCTestCase {
    private var directory: URL!
    private var account: String!

    override func setUpWithError() throws {
        directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("vv-recovery-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        account = "vault.master.\(directory.lastPathComponent)"
        KeychainMasterKey.deleteForTests(account: account)
    }

    override func tearDownWithError() throws {
        KeychainMasterKey.deleteForTests(account: account)
        try? FileManager.default.removeItem(at: directory)
    }

    func testRecoveryKeyRestoresMissingKeychainMasterKey() throws {
        let store = EncryptedVaultStore(directory: directory)
        try store.add(Secret(name: "TOKEN", value: "recover-me"))
        let recoveryKey = try CloudRecoveryKey.generate()
        try LocalVaultRecovery.protect(directory: directory, recoveryKey: recoveryKey)

        KeychainMasterKey.deleteForTests(account: account)
        XCTAssertThrowsError(try EncryptedVaultStore(directory: directory).list()) {
            XCTAssertEqual($0 as? LocalVaultRecoveryError, .masterKeyUnavailable)
        }

        try LocalVaultRecovery.restore(directory: directory, recoveryKey: recoveryKey)

        XCTAssertEqual(
            try EncryptedVaultStore(directory: directory).read(name: "TOKEN").value,
            "recover-me"
        )
    }

    func testWrongRecoveryKeyDoesNotInstallAReplacementKey() throws {
        let store = EncryptedVaultStore(directory: directory)
        try store.add(Secret(name: "TOKEN", value: "keep-me"))
        try LocalVaultRecovery.protect(
            directory: directory,
            recoveryKey: CloudRecoveryKey.generate()
        )
        KeychainMasterKey.deleteForTests(account: account)

        XCTAssertThrowsError(
            try LocalVaultRecovery.restore(
                directory: directory,
                recoveryKey: CloudRecoveryKey.generate()
            )
        ) {
            XCTAssertEqual($0 as? LocalVaultRecoveryError, .authenticationFailed)
        }
        XCTAssertThrowsError(try EncryptedVaultStore(directory: directory).list()) {
            XCTAssertEqual($0 as? LocalVaultRecoveryError, .masterKeyUnavailable)
        }
    }

    func testExistingVaultWithoutMasterKeyNeverCreatesANewKey() throws {
        let store = EncryptedVaultStore(directory: directory)
        try store.add(Secret(name: "TOKEN", value: "keep-me"))
        KeychainMasterKey.deleteForTests(account: account)

        XCTAssertThrowsError(try EncryptedVaultStore(directory: directory).list()) {
            XCTAssertEqual($0 as? LocalVaultRecoveryError, .masterKeyUnavailable)
        }
        XCTAssertFalse(KeychainMasterKey.exists(account: account))
    }

    func testRecoveryEnvelopeAndVaultRemainEligibleForTimeMachine() throws {
        let directory = try XCTUnwrap(directory)
        let store = EncryptedVaultStore(directory: directory)
        try store.add(Secret(name: "TOKEN", value: "recover-me"))
        try LocalVaultRecovery.protect(
            directory: directory,
            recoveryKey: CloudRecoveryKey.generate()
        )

        for url in [
            directory,
            directory.appendingPathComponent("secrets.vault"),
            directory.appendingPathComponent(LocalVaultRecovery.fileName)
        ] {
            let values = try url.resourceValues(forKeys: [.isExcludedFromBackupKey])
            XCTAssertNotEqual(values.isExcludedFromBackup, true, "excluded from backup: \(url.path)")
        }
    }
}
