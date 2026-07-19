import CryptoKit
import Foundation

public struct CloudSyncSnapshot: Codable, Equatable, Sendable {
    public let version: Int
    public let exportedAt: Date
    public let sourceHost: String
    public let secrets: [CloudSyncSecret]

    public init(
        version: Int = 1,
        exportedAt: Date = Date(),
        sourceHost: String = ProcessInfo.processInfo.hostName,
        secrets: [CloudSyncSecret]
    ) {
        self.version = version
        self.exportedAt = exportedAt
        self.sourceHost = sourceHost
        self.secrets = secrets
    }
}

public struct CloudSyncSecret: Codable, Equatable, Sendable {
    public let name: String
    public let value: String
    public let createdAt: Date
    public let updatedAt: Date
    public let notes: String?
    public let expiresAt: Date?
    public let rotateEveryDays: Int?
    public let lastRotatedAt: Date?
    public let mcpAllowed: Bool

    enum CodingKeys: String, CodingKey {
        case name
        case value
        case createdAt
        case updatedAt
        case notes
        case expiresAt
        case rotateEveryDays
        case lastRotatedAt
        case mcpAllowed
    }

    public init(
        name: String,
        value: String,
        createdAt: Date? = nil,
        updatedAt: Date = Date(),
        notes: String? = nil,
        expiresAt: Date? = nil,
        rotateEveryDays: Int? = nil,
        lastRotatedAt: Date? = nil,
        mcpAllowed: Bool = false
    ) {
        self.name = name
        self.value = value
        self.createdAt = createdAt ?? updatedAt
        self.updatedAt = updatedAt
        self.notes = notes
        self.expiresAt = expiresAt
        self.rotateEveryDays = rotateEveryDays
        self.lastRotatedAt = lastRotatedAt
        self.mcpAllowed = mcpAllowed
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = try container.decode(String.self, forKey: .name)
        value = try container.decode(String.self, forKey: .value)
        updatedAt = try container.decode(Date.self, forKey: .updatedAt)
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt) ?? updatedAt
        notes = try container.decodeIfPresent(String.self, forKey: .notes)
        expiresAt = try container.decodeIfPresent(Date.self, forKey: .expiresAt)
        rotateEveryDays = try container.decodeIfPresent(Int.self, forKey: .rotateEveryDays)
        lastRotatedAt = try container.decodeIfPresent(Date.self, forKey: .lastRotatedAt)
        mcpAllowed = try container.decodeIfPresent(Bool.self, forKey: .mcpAllowed) ?? false
    }

    public init(secret: Secret) {
        self.init(
            name: secret.name,
            value: secret.value,
            createdAt: secret.createdAt,
            updatedAt: secret.updatedAt,
            notes: secret.notes,
            expiresAt: secret.expiresAt,
            rotateEveryDays: secret.rotateEveryDays,
            lastRotatedAt: secret.lastRotatedAt,
            mcpAllowed: secret.mcpAllowed
        )
    }

    public func asSecret() -> Secret {
        Secret(
            name: name,
            value: value,
            updatedAt: updatedAt,
            createdAt: createdAt,
            notes: notes,
            expiresAt: expiresAt,
            rotateEveryDays: rotateEveryDays,
            lastRotatedAt: lastRotatedAt,
            mcpAllowed: mcpAllowed
        )
    }
}

public struct CloudSyncEnvelope: Codable, Equatable, Sendable {
    public let version: Int
    public let createdAt: Date
    public let sourceHost: String
    public let kdf: String
    public let cipher: String
    public let salt: String
    public let nonce: String
    public let tag: String
    public let ciphertext: String
}

public enum CloudSyncError: Error, Equatable, CustomStringConvertible {
    case weakPassphrase
    case unsupportedVersion(Int)
    case corruptEnvelope
    case authenticationFailed

    public var description: String {
        switch self {
        case .weakPassphrase:
            return "sync passphrase must be at least 12 characters"
        case .unsupportedVersion(let version):
            return "unsupported sync bundle version: \(version)"
        case .corruptEnvelope:
            return "corrupt sync bundle"
        case .authenticationFailed:
            return "could not decrypt sync bundle; check the passphrase"
        }
    }
}

public enum CloudSync {
    public static let fileName = "vault.vvsync"
    private static let version = 1
    private static let kdf = "hkdf-sha256"
    private static let cipher = "aes-256-gcm"
    private static let info = Data("vibevault-cloud-sync-v1".utf8)

    public static func defaultICloudURL() -> URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Mobile Documents/com~apple~CloudDocs/Documents")
            .appendingPathComponent("VibeVault/Sync", isDirectory: true)
            .appendingPathComponent(fileName)
    }

    public static func encrypt(_ snapshot: CloudSyncSnapshot, passphrase: String) throws -> Data {
        try validatePassphrase(passphrase)
        let salt = randomData(count: 32)
        let key = deriveKey(passphrase: passphrase, salt: salt)
        let plain = try encoder.encode(snapshot)
        let sealed = try AES.GCM.seal(plain, using: key)
        let envelope = CloudSyncEnvelope(
            version: version,
            createdAt: Date(),
            sourceHost: snapshot.sourceHost,
            kdf: kdf,
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
              let salt = Data(base64Encoded: envelope.salt),
              let nonceData = Data(base64Encoded: envelope.nonce),
              let tag = Data(base64Encoded: envelope.tag),
              let ciphertext = Data(base64Encoded: envelope.ciphertext) else {
            throw CloudSyncError.corruptEnvelope
        }
        let key = deriveKey(passphrase: passphrase, salt: salt)
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

    private static func deriveKey(passphrase: String, salt: Data) -> SymmetricKey {
        HKDF<SHA256>.deriveKey(
            inputKeyMaterial: SymmetricKey(data: Data(passphrase.utf8)),
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
