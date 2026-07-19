import CommonCrypto
import CryptoKit
import Foundation

public enum CloudSync {
    public static let fileName = "vault.vvsync"
    private static let version = 1
    private static let kdf = "pbkdf2-sha256+hkdf-sha256"
    private static let cipher = "aes-256-gcm"
    private static let info = Data("vibevault-cloud-sync-v1".utf8)
    private static let kdfIterations = 600_000
    // Lower bound blocks downgrade to a fast KDF; upper bound blocks DoS via a hostile envelope.
    private static let kdfIterationRange = 600_000...10_000_000

    public static func defaultICloudURL() -> URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Mobile Documents/com~apple~CloudDocs/Documents")
            .appendingPathComponent("VibeVault/Sync", isDirectory: true)
            .appendingPathComponent(fileName)
    }

    public static func encrypt(_ snapshot: CloudSyncSnapshot, passphrase: String) throws -> Data {
        try validatePassphrase(passphrase)
        let salt = randomData(count: 32)
        let key = try deriveKey(passphrase: passphrase, salt: salt, iterations: kdfIterations)
        let plain = try encoder.encode(snapshot)
        let sealed = try AES.GCM.seal(plain, using: key)
        let envelope = CloudSyncEnvelope(
            version: version,
            createdAt: Date(),
            sourceHost: snapshot.sourceHost,
            kdf: kdf,
            kdfIterations: kdfIterations,
            cipher: cipher,
            salt: salt.base64EncodedString(),
            nonce: sealed.nonce.withUnsafeBytes { Data($0).base64EncodedString() },
            tag: sealed.tag.base64EncodedString(),
            ciphertext: sealed.ciphertext.base64EncodedString()
        )
        return try encoder.encode(envelope)
    }

    public static func decrypt(_ data: Data, passphrase: String) throws -> CloudSyncSnapshot {
        let envelope = try decoder.decode(CloudSyncEnvelope.self, from: data)
        guard envelope.version == version else { throw CloudSyncError.unsupportedVersion(envelope.version) }
        guard envelope.kdf == kdf, envelope.cipher == cipher,
              kdfIterationRange.contains(envelope.kdfIterations),
              let salt = Data(base64Encoded: envelope.salt),
              let nonceData = Data(base64Encoded: envelope.nonce),
              let tag = Data(base64Encoded: envelope.tag),
              let ciphertext = Data(base64Encoded: envelope.ciphertext) else {
            throw CloudSyncError.corruptEnvelope
        }
        let key = try deriveKey(passphrase: passphrase, salt: salt, iterations: envelope.kdfIterations)
        do {
            let nonce = try AES.GCM.Nonce(data: nonceData)
            let box = try AES.GCM.SealedBox(nonce: nonce, ciphertext: ciphertext, tag: tag)
            let plain = try AES.GCM.open(box, using: key)
            let snapshot = try decoder.decode(CloudSyncSnapshot.self, from: plain)
            guard snapshot.version == version else {
                throw CloudSyncError.unsupportedVersion(snapshot.version)
            }
            return snapshot
        } catch let error as CloudSyncError {
            throw error
        } catch {
            throw CloudSyncError.authenticationFailed
        }
    }

    public static func write(_ data: Data, to url: URL) throws {
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try data.write(to: url, options: .atomic)
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
    }

    private static func validatePassphrase(_ passphrase: String) throws {
        guard passphrase.count >= 12 else { throw CloudSyncError.weakPassphrase }
    }

    // Passphrases must pass through a slow KDF before HKDF: HKDF alone offers no
    // brute-force resistance. PBKDF2 stretches; HKDF binds the result to this format's info string.
    private static func deriveKey(passphrase: String, salt: Data, iterations: Int) throws -> SymmetricKey {
        var stretched = Data(count: 32)
        let passphraseLength = passphrase.utf8.count
        let status = stretched.withUnsafeMutableBytes { stretchedBytes in
            salt.withUnsafeBytes { saltBytes in
                CCKeyDerivationPBKDF(
                    CCPBKDFAlgorithm(kCCPBKDF2),
                    passphrase, passphraseLength,
                    saltBytes.bindMemory(to: UInt8.self).baseAddress, salt.count,
                    CCPseudoRandomAlgorithm(kCCPRFHmacAlgSHA256),
                    UInt32(iterations),
                    stretchedBytes.bindMemory(to: UInt8.self).baseAddress, 32
                )
            }
        }
        guard status == kCCSuccess else { throw CloudSyncError.keyDerivationFailed }
        return HKDF<SHA256>.deriveKey(
            inputKeyMaterial: SymmetricKey(data: stretched),
            salt: salt,
            info: info,
            outputByteCount: 32
        )
    }

    private static func randomData(count: Int) -> Data {
        Data((0..<count).map { _ in UInt8.random(in: UInt8.min...UInt8.max) })
    }

    private static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        return encoder
    }()

    private static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()
}
