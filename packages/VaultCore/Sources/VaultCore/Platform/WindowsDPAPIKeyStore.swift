#if os(Windows)
import Foundation
import WinSDK

/// Protects the vault master key with DPAPI (`CryptProtectData`) bound to the current user.
enum WindowsDPAPIKeyStore {
    static var isImplemented: Bool { true }
    private static let filePrefix = "master."
    private static let fileSuffix = ".dpapi"
    private static let magic = Data("VVDP1".utf8)

    static func blobURL(account: String, directory: URL) -> URL {
        let safe = account.replacingOccurrences(of: "/", with: "_")
        return directory.appendingPathComponent("\(filePrefix)\(safe)\(fileSuffix)")
    }

    static func loadMasterKey(account: String, directory: URL = VaultPaths.defaultDirectory()) throws -> SymmetricKey? {
        if let migrated = try migratePlaintextIfNeeded(account: account, directory: directory) {
            return migrated
        }
        let url = blobURL(account: account, directory: directory)
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        let file = try Data(contentsOf: url)
        guard file.count > magic.count, file.prefix(magic.count) == magic else {
            throw SecretError.vaultIO("corrupt DPAPI master key file")
        }
        let protected = file.dropFirst(magic.count)
        let plain = try unprotect(Data(protected))
        guard plain.count == 32 else { throw SecretError.vaultIO("corrupt DPAPI master key") }
        return SymmetricKey(data: plain)
    }

    static func storeMasterKey(_ key: SymmetricKey, account: String, directory: URL = VaultPaths.defaultDirectory()) throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let plain = key.withUnsafeBytes { Data($0) }
        guard plain.count == 32 else { throw SecretError.vaultIO("master key must be 32 bytes") }
        let protected = try protect(plain)
        var file = magic
        file.append(protected)
        let url = blobURL(account: account, directory: directory)
        try file.write(to: url, options: .atomic)
        PlatformFilePermissions.restrictToOwner(url)
        VaultPaths.excludeFromBackup(url)
        FileSecureStore.deleteMasterKey(account: account, directory: directory)
    }

    static func deleteMasterKey(account: String, directory: URL = VaultPaths.defaultDirectory()) {
        try? FileManager.default.removeItem(at: blobURL(account: account, directory: directory))
        FileSecureStore.deleteMasterKey(account: account, directory: directory)
    }

    static func masterKeyExists(account: String, directory: URL = VaultPaths.defaultDirectory()) -> Bool {
        FileManager.default.fileExists(atPath: blobURL(account: account, directory: directory).path)
            || FileSecureStore.masterKeyExists(account: account, directory: directory)
    }

    private static func migratePlaintextIfNeeded(account: String, directory: URL) throws -> SymmetricKey? {
        let url = blobURL(account: account, directory: directory)
        if FileManager.default.fileExists(atPath: url.path) { return nil }
        guard let existing = try FileSecureStore.loadMasterKey(account: account, directory: directory) else {
            return nil
        }
        try storeMasterKey(existing, account: account, directory: directory)
        return existing
    }

    private static func protect(_ plaintext: Data) throws -> Data {
        try crypt(plaintext, protect: true)
    }

    private static func unprotect(_ blob: Data) throws -> Data {
        try crypt(blob, protect: false)
    }

    private static func crypt(_ data: Data, protect: Bool) throws -> Data {
        try data.withUnsafeBytes { raw in
            guard let base = raw.bindMemory(to: UInt8.self).baseAddress else {
                throw SecretError.vaultIO("DPAPI empty buffer")
            }
            var input = DATA_BLOB(cbData: DWORD(raw.count), pbData: UnsafeMutablePointer(mutating: base))
            var output = DATA_BLOB()
            let flags: DWORD = 0x1 // CRYPTPROTECT_UI_FORBIDDEN
            let ok: Bool
            if protect {
                ok = "Vibe Vault master key".withCString(encodedAs: UTF16.self) { descr in
                    CryptProtectData(&input, descr, nil, nil, nil, flags, &output)
                }
            } else {
                ok = CryptUnprotectData(&input, nil, nil, nil, nil, flags, &output)
            }
            guard ok else {
                throw SecretError.vaultIO("DPAPI \(protect ? "protect" : "unprotect") failed (\(GetLastError()))")
            }
            defer { _ = LocalFree(output.pbData) }
            guard let outBase = output.pbData, output.cbData > 0 else {
                throw SecretError.vaultIO("DPAPI returned empty blob")
            }
            return Data(bytes: outBase, count: Int(output.cbData))
        }
    }
}
#endif
