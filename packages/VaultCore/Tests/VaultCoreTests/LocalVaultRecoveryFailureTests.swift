import Security
import XCTest
@testable import VaultCore

final class LocalVaultRecoveryFailureTests: XCTestCase {
    private var directory: URL!
    private var account: String!

    override func setUpWithError() throws {
        directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("vv-recovery-failure-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        account = KeychainMasterKey.account(forVaultDirectory: directory)
        KeychainMasterKey.deleteForTests(account: account)
    }

    override func tearDownWithError() throws {
        KeychainMasterKey.deleteForTests(account: account)
        try? FileManager.default.removeItem(at: directory)
    }

    func testProtectionCanBeConfiguredBeforeFirstSecret() throws {
        let recoveryKey = try CloudRecoveryKey.generate()
        try LocalVaultRecovery.protect(directory: directory, recoveryKey: recoveryKey)
        XCTAssertTrue(LocalVaultRecovery.isProtected(directory: directory))

        try EncryptedVaultStore(directory: directory).add(Secret(name: "TOKEN", value: "future"))
        KeychainMasterKey.deleteForTests(account: account)
        try LocalVaultRecovery.restore(directory: directory, recoveryKey: recoveryKey)

        XCTAssertEqual(
            try EncryptedVaultStore(directory: directory).read(name: "TOKEN").value,
            "future"
        )
    }

    func testRestoreRequiresVaultAndEnvelope() throws {
        let key = try CloudRecoveryKey.generate()
        XCTAssertThrowsError(try LocalVaultRecovery.restore(directory: directory, recoveryKey: key)) {
            XCTAssertEqual($0 as? LocalVaultRecoveryError, .vaultMissing)
        }

        try EncryptedVaultStore(directory: directory).add(Secret(name: "TOKEN", value: "value"))
        XCTAssertThrowsError(try LocalVaultRecovery.restore(directory: directory, recoveryKey: key)) {
            XCTAssertEqual($0 as? LocalVaultRecoveryError, .recoveryEnvelopeMissing)
        }
    }

    func testCorruptAndUnsupportedEnvelopesAreRejected() throws {
        let key = try CloudRecoveryKey.generate()
        try EncryptedVaultStore(directory: directory).add(Secret(name: "TOKEN", value: "value"))
        let envelopeURL = directory.appendingPathComponent(LocalVaultRecovery.fileName)
        try Data("not-json".utf8).write(to: envelopeURL)
        XCTAssertThrowsError(try LocalVaultRecovery.restore(directory: directory, recoveryKey: key)) {
            XCTAssertEqual($0 as? LocalVaultRecoveryError, .corruptEnvelope)
        }

        try LocalVaultRecovery.protect(directory: directory, recoveryKey: key)
        try editEnvelope(envelopeURL) { $0["version"] = 99 }
        XCTAssertThrowsError(try LocalVaultRecovery.restore(directory: directory, recoveryKey: key)) {
            XCTAssertEqual($0 as? LocalVaultRecoveryError, .unsupportedVersion(99))
        }
    }

    func testInvalidEnvelopeKDFIsRejectedWithoutChangingKeychain() throws {
        let key = try CloudRecoveryKey.generate()
        try EncryptedVaultStore(directory: directory).add(Secret(name: "TOKEN", value: "value"))
        try LocalVaultRecovery.protect(directory: directory, recoveryKey: key)
        let envelopeURL = directory.appendingPathComponent(LocalVaultRecovery.fileName)
        try editEnvelope(envelopeURL) { $0["kdf"] = "UNSUPPORTED" }
        KeychainMasterKey.deleteForTests(account: account)

        XCTAssertThrowsError(try LocalVaultRecovery.restore(directory: directory, recoveryKey: key)) {
            XCTAssertEqual($0 as? LocalVaultRecoveryError, .corruptEnvelope)
        }
        XCTAssertFalse(KeychainMasterKey.exists(account: account))
    }

    func testMalformedKeychainItemIsReportedAsRecoverable() throws {
        try EncryptedVaultStore(directory: directory).add(Secret(name: "TOKEN", value: "value"))
        KeychainMasterKey.deleteForTests(account: account)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: KeychainMasterKey.service,
            kSecAttrAccount as String: account!,
            kSecValueData as String: Data("bad".utf8)
        ]
        XCTAssertEqual(SecItemAdd(query as CFDictionary, nil), errSecSuccess)

        XCTAssertThrowsError(try EncryptedVaultStore(directory: directory).list()) {
            XCTAssertEqual($0 as? LocalVaultRecoveryError, .masterKeyUnavailable)
        }
    }

    private func editEnvelope(
        _ url: URL,
        mutation: (inout [String: Any]) -> Void
    ) throws {
        var json = try XCTUnwrap(
            JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any]
        )
        mutation(&json)
        try JSONSerialization.data(withJSONObject: json).write(to: url, options: .atomic)
    }
}
