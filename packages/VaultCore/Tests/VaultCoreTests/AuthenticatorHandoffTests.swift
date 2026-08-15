import XCTest
@testable import VaultCore

final class AuthenticatorHandoffTests: XCTestCase {
    func test_pendingBrowserHandoffIsEncryptedConsumedOnceAndDeleted() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("vv-handoff-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let account = "vault.master.\(directory.lastPathComponent)"
        defer {
            KeychainMasterKey.deleteForTests(account: account)
            try? FileManager.default.removeItem(at: directory)
        }
        let uri = "otpauth://totp/Example:alice?secret=JBSWY3DPEHPK3PXP&issuer=Example"

        try AuthenticatorHandoff.enqueue(uri, directory: directory)
        let raw = try Data(contentsOf: AuthenticatorHandoff.pendingURL(in: directory))

        XCTAssertFalse(String(data: raw, encoding: .utf8)?.contains("JBSWY3DPEHPK3PXP") == true)
        XCTAssertEqual(try AuthenticatorHandoff.consume(directory: directory), uri)
        XCTAssertNil(try AuthenticatorHandoff.consume(directory: directory))
    }
}
