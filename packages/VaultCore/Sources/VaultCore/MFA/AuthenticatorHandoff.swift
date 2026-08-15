import CryptoKit
import Foundation

public enum AuthenticatorHandoff {
    public static let notificationName = "dev.vibevault.authenticator-handoff"
    private static let filename = "pending-authenticator.vvrequest"

    public static func pendingURL(
        in directory: URL = EncryptedVaultStore.defaultDirectory()
    ) -> URL {
        directory.appendingPathComponent(filename)
    }

    public static func enqueue(
        _ input: String,
        directory: URL = EncryptedVaultStore.defaultDirectory()
    ) throws {
        guard input.utf8.count <= 16_384 else { throw TOTPError.invalidParameter("input size") }
        _ = try TOTPGenerator.account(from: input)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let blob = try VaultFileCrypto.seal(Data(input.utf8), key: masterKey(for: directory))
        let url = pendingURL(in: directory)
        try blob.write(to: url, options: .atomic)
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
        VaultPaths.excludeFromBackup(url)
    }

    public static func consume(
        directory: URL = EncryptedVaultStore.defaultDirectory()
    ) throws -> String? {
        let url = pendingURL(in: directory)
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        let plain = try VaultFileCrypto.open(Data(contentsOf: url), key: masterKey(for: directory))
        guard let input = String(data: plain, encoding: .utf8) else { throw TOTPError.invalidURL }
        _ = try TOTPGenerator.account(from: input)
        try FileManager.default.removeItem(at: url)
        return input
    }

    private static func masterKey(for directory: URL) throws -> SymmetricKey {
        let leaf = directory.standardizedFileURL.lastPathComponent
        let account = leaf == "vibe-vault"
            ? KeychainMasterKey.defaultAccount
            : "vault.master.\(leaf)"
        return try VaultFileCrypto.loadOrCreateKey(
            legacyFileURL: directory.appendingPathComponent("master.key"), account: account
        )
    }
}
