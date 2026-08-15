import XCTest
@testable import VaultCore

final class AuthenticatorServiceTests: XCTestCase {
    private var directory: URL!
    private var databaseURL: URL!
    private var keyAccount: String!
    private var service: AuthenticatorService!

    override func setUpWithError() throws {
        directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("vv-authenticator-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        databaseURL = directory.appendingPathComponent("audit.db")
        keyAccount = "vault.master.\(directory.lastPathComponent)"
        service = AuthenticatorService(
            store: EncryptedVaultStore(directory: directory),
            audit: try AuditDB(url: databaseURL),
            detector: StubAgentDetector(),
            biometric: NoopBiometricGate(),
            sessionId: "auth-test"
        )
    }

    override func tearDownWithError() throws {
        KeychainMasterKey.deleteForTests(account: keyAccount)
        try? FileManager.default.removeItem(at: directory)
    }

    func test_userCanEnrollListAndGenerateAStandaloneCode() async throws {
        let account = try await service.add(
            input: "GEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQ",
            issuer: "Example",
            accountName: "alice@example.com"
        )
        let listed = try service.list()

        XCTAssertEqual(listed.count, 1)
        XCTAssertEqual(listed[0].id, account.id)
        XCTAssertEqual(listed[0].issuer, "Example")
        XCTAssertEqual(listed[0].accountName, "alice@example.com")
        let code = try await service.code(
            id: account.id,
            reason: "Show authenticator code",
            at: Date(timeIntervalSince1970: 59)
        )
        XCTAssertEqual(code.code, "287082")
        XCTAssertEqual(code.secondsRemaining, 1)
    }

    func test_recoveryCodesAreRevealedOneAtATimeAndExplicitlyMarkedUsed() async throws {
        let account = try await service.add(
            input: "GEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQ",
            issuer: "Example",
            accountName: "alice@example.com"
        )
        try await service.addRecoveryCodes(id: account.id, values: ["FIRST-111", "SECOND-222"])

        let first = try await service.nextRecoveryCode(id: account.id)
        XCTAssertEqual(first.value, "FIRST-111")
        try await service.markRecoveryCodeUsed(id: account.id, recoveryCodeID: first.id)

        let second = try await service.nextRecoveryCode(id: account.id)
        XCTAssertEqual(second.value, "SECOND-222")
        XCTAssertEqual(try service.list().first?.unusedRecoveryCodeCount, 1)
    }

    func test_encryptedBackupExportAndImportPreserveAuthenticatorAccounts() async throws {
        let saved = try await service.add(
            input: "GEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQ",
            issuer: "Example",
            accountName: "alice@example.com"
        )
        let exported = try await service.accountsForEncryptedBackup()

        let otherDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("vv-auth-import-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: otherDirectory, withIntermediateDirectories: true)
        defer {
            KeychainMasterKey.deleteForTests(account: "vault.master.\(otherDirectory.lastPathComponent)")
            try? FileManager.default.removeItem(at: otherDirectory)
        }
        let other = AuthenticatorService(
            store: EncryptedVaultStore(directory: otherDirectory),
            audit: try AuditDB(url: otherDirectory.appendingPathComponent("audit.db")),
            detector: StubAgentDetector(), biometric: NoopBiometricGate()
        )

        let result = try await other.importAccounts(exported, duplicatePolicy: .skip)

        XCTAssertEqual(result.imported, [saved.id])
        XCTAssertEqual(try other.list().first?.issuer, "Example")
    }

    func test_userCanEditMetadataAndDeleteAnAuthenticator() async throws {
        let account = try await service.add(
            input: "GEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQ",
            issuer: "Example",
            accountName: "alice@example.com"
        )
        try await service.updateMetadata(
            id: account.id, issuer: "Example Inc", accountName: "alice", favorite: true
        )

        XCTAssertEqual(try service.list().first?.issuer, "Example Inc")
        XCTAssertEqual(try service.list().first?.favorite, true)
        try await service.delete(id: account.id)
        XCTAssertTrue(try service.list().isEmpty)
    }

    func test_attachedTOTPConvertsToStandaloneWithoutLosingTheCredential() async throws {
        let store = EncryptedVaultStore(directory: directory)
        let vault = VaultService(
            store: store, audit: try AuditDB(url: databaseURL),
            detector: StubAgentDetector(), biometric: NoopBiometricGate()
        )
        let uri = "otpauth://totp/Example:alice@example.com?secret=JBSWY3DPEHPK3PXP&issuer=Example"
        try vault.add(name: "EXAMPLE_PASSWORD", value: "credential", totpAuthURL: uri)
        let authenticator = try AuthenticatorService(vaultService: vault)

        let converted = try await authenticator.convertAttachedTOTP(
            secretName: "EXAMPLE_PASSWORD", vaultService: vault
        )

        XCTAssertEqual(converted.issuer, "Example")
        XCTAssertEqual(try store.read(name: "EXAMPLE_PASSWORD").value, "credential")
        XCTAssertNil(try store.read(name: "EXAMPLE_PASSWORD").totpAuthURL)
    }

    func test_seedCanBeReplacedWithoutChangingAccountIdentity() async throws {
        let account = try await service.add(
            input: "GEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQ",
            issuer: "Example", accountName: "alice"
        )
        let before = try await service.code(
            id: account.id, at: Date(timeIntervalSince1970: 59)
        )

        try await service.replaceSeed(id: account.id, input: "JBSWY3DPEHPK3PXP")
        let after = try await service.code(
            id: account.id, at: Date(timeIntervalSince1970: 59)
        )

        XCTAssertNotEqual(before.code, after.code)
        XCTAssertEqual(try service.list().first?.id, account.id)
    }
}
