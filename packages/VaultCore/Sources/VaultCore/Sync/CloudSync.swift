import Foundation
#if canImport(Security)
import Security
#endif

public enum CloudSync {
    public static let fileName = "vault.vvsync"
    static let legacyVersion = 1
    static let version = 2
    static let kdf = "pbkdf2-sha256+hkdf-sha256"
    static let recoveryKdf = "hkdf-sha256"
    static let cipher = "aes-256-gcm"
    static let info = Data("vibevault-cloud-sync-v2".utf8)
    static let legacyInfo = Data("vibevault-cloud-sync-v1".utf8)
    static let recoveryInfo = Data("vibevault-cloud-recovery-v2".utf8)
    static let kdfIterations = 600_000
    static let kdfIterationRange = 600_000...10_000_000

    public static func iCloudDriveRootURL() -> URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Mobile Documents/com~apple~CloudDocs", isDirectory: true)
    }

    public static func isICloudDriveAvailable(
        at rootURL: URL = iCloudDriveRootURL(),
        fileManager: FileManager = .default
    ) -> Bool {
        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: rootURL.path, isDirectory: &isDirectory),
              isDirectory.boolValue else {
            return false
        }
        return fileManager.isWritableFile(atPath: rootURL.path)
    }

    public static func defaultICloudURL() -> URL {
        iCloudDriveRootURL()
            .appendingPathComponent("Documents")
            .appendingPathComponent("VibeVault/Sync", isDirectory: true)
            .appendingPathComponent(fileName)
    }

    public static func encrypt(
        _ snapshot: CloudSyncSnapshot,
        passphrase: String,
        recoveryKey: String? = nil
    ) throws -> Data {
        try validatePassphrase(passphrase)
        let salt = try secureRandomData(count: 32)
        let passphraseKey = try derivePassphraseKey(
            passphrase: passphrase,
            salt: salt,
            iterations: kdfIterations,
            info: info
        )
        let dataKeyBytes = try secureRandomData(count: 32)
        let dataKey = SymmetricKey(data: dataKeyBytes)
        let sealed = try AES.GCM.seal(try encoder.encode(snapshot), using: dataKey)
        let passphraseWrap = try AES.GCM.seal(dataKeyBytes, using: passphraseKey)

        var recoverySalt: Data?
        var recoveryWrap: AES.GCM.SealedBox?
        var recoveryKeyID: String?
        var recoveryProtectedAt: Date?
        if let recoveryKey {
            let wrap = try wrapRecovery(dataKeyBytes: dataKeyBytes, recoveryKey: recoveryKey)
            recoverySalt = wrap.salt
            recoveryWrap = wrap.box
            recoveryKeyID = wrap.keyID
            recoveryProtectedAt = wrap.protectedAt
        }

        let envelope = CloudSyncEnvelope(
            version: version,
            createdAt: Date(),
            sourceHost: snapshot.sourceHost,
            kdf: kdf,
            kdfIterations: kdfIterations,
            cipher: cipher,
            salt: salt.base64EncodedString(),
            nonce: encodedNonce(sealed),
            tag: sealed.tag.base64EncodedString(),
            ciphertext: sealed.ciphertext.base64EncodedString(),
            passphraseNonce: encodedNonce(passphraseWrap),
            passphraseTag: passphraseWrap.tag.base64EncodedString(),
            passphraseWrappedKey: passphraseWrap.ciphertext.base64EncodedString(),
            recoveryKdf: recoveryWrap == nil ? nil : recoveryKdf,
            recoverySalt: recoverySalt?.base64EncodedString(),
            recoveryNonce: recoveryWrap.map(encodedNonce),
            recoveryTag: recoveryWrap?.tag.base64EncodedString(),
            recoveryWrappedKey: recoveryWrap?.ciphertext.base64EncodedString(),
            recoveryKeyID: recoveryKeyID,
            recoveryProtectedAt: recoveryProtectedAt
        )
        return try encoder.encode(envelope)
    }

    public static func write(_ data: Data, to url: URL) throws {
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try data.write(to: url, options: .atomic)
        PlatformFilePermissions.restrictToOwner(url)
    }

    static func validatePassphrase(_ passphrase: String) throws {
        guard passphrase.count >= 12 else { throw CloudSyncError.weakPassphrase }
    }

    static func derivePassphraseKey(
        passphrase: String,
        salt: Data,
        iterations: Int,
        info: Data
    ) throws -> SymmetricKey {
        let stretched = try PlatformPBKDF2.derive(
            passphrase: passphrase,
            salt: salt,
            iterations: iterations,
            byteCount: 32
        )
        return HKDF<SHA256>.deriveKey(
            inputKeyMaterial: SymmetricKey(data: stretched),
            salt: salt,
            info: info,
            outputByteCount: 32
        )
    }

    static func deriveRecoveryKey(keyMaterial: Data, salt: Data) -> SymmetricKey {
        HKDF<SHA256>.deriveKey(
            inputKeyMaterial: SymmetricKey(data: keyMaterial),
            salt: salt,
            info: recoveryInfo,
            outputByteCount: 32
        )
    }

    static func encodedNonce(_ box: AES.GCM.SealedBox) -> String {
        box.nonce.withUnsafeBytes { Data($0).base64EncodedString() }
    }

    static func secureRandomData(count: Int) throws -> Data {
        Data(try PlatformRandom.bytes(count: count))
    }

    static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        return encoder
    }()

    static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()
}
