import Darwin
import CryptoKit
import Foundation

public struct SharedUnlockSessionStatus: Equatable, Sendable {
    public let id: UUID
    public let issuedAt: Date
    public let expiresAt: Date

    public func remainingSeconds(at date: Date = Date()) -> TimeInterval {
        max(0, expiresAt.timeIntervalSince(date))
    }
}

/// An explicit, time-bounded authentication lease shared by VibeVault clients
/// running as the current macOS user. The lease never contains vault secrets.
public enum SharedUnlockSession {
    public static let minimumDuration: TimeInterval = 5 * 60
    public static let maximumDuration: TimeInterval = 8 * 60 * 60
    private static let keyQueue = DispatchQueue(label: "dev.vibevault.unlock-session-key")
    private static var cachedKeys: [String: SymmetricKey] = [:]

    private struct Payload: Codable {
        let version: Int
        let id: UUID
        let issuedAt: Int64
        let expiresAt: Int64
        let authenticationCode: Data
    }

    public static func defaultURL() -> URL {
        VaultPaths.defaultDirectory().appendingPathComponent("unlock-session.json")
    }

    @discardableResult
    public static func unlock(
        for duration: TimeInterval,
        at date: Date = Date(),
        url: URL = defaultURL(),
        authenticationKey: SymmetricKey? = nil
    ) throws -> SharedUnlockSessionStatus {
        let bounded = min(max(duration, minimumDuration), maximumDuration)
        let issuedAt = Int64(date.timeIntervalSince1970.rounded(.down))
        let expiresAt = issuedAt + Int64(bounded.rounded(.down))
        let id = UUID()
        let key = try authenticationKey ?? defaultAuthenticationKey(for: url)
        let payload = Payload(
            version: 1,
            id: id,
            issuedAt: issuedAt,
            expiresAt: expiresAt,
            authenticationCode: Data(HMAC<SHA256>.authenticationCode(
                for: authenticationMessage(
                    version: 1,
                    id: id,
                    issuedAt: issuedAt,
                    expiresAt: expiresAt
                ),
                using: key
            ))
        )
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let encoder = JSONEncoder()
        try encoder.encode(payload).write(to: url, options: .atomic)
        try FileManager.default.setAttributes(
            [.posixPermissions: 0o600],
            ofItemAtPath: url.path
        )
        VaultPaths.excludeFromBackup(url)
        return status(at: date, url: url, authenticationKey: key)!
    }

    public static func status(
        at date: Date = Date(),
        url: URL = defaultURL(),
        authenticationKey: SymmetricKey? = nil
    ) -> SharedUnlockSessionStatus? {
        guard isPrivateRegularFile(url) else { return nil }
        guard let data = try? Data(contentsOf: url),
              let payload = try? JSONDecoder().decode(Payload.self, from: data) else {
            lock(url: url)
            return nil
        }
        let key: SymmetricKey
        do {
            key = try authenticationKey ?? defaultAuthenticationKey(for: url)
        } catch {
            // A denied Keychain lookup must not revoke a valid session for
            // clients that already have access.
            return nil
        }
        let issuedAt = Date(timeIntervalSince1970: TimeInterval(payload.issuedAt))
        let expiresAt = Date(timeIntervalSince1970: TimeInterval(payload.expiresAt))
        let message = authenticationMessage(
            version: payload.version,
            id: payload.id,
            issuedAt: payload.issuedAt,
            expiresAt: payload.expiresAt
        )
        guard payload.version == 1,
              HMAC<SHA256>.isValidAuthenticationCode(
                payload.authenticationCode,
                authenticating: message,
                using: key
              ),
              issuedAt <= date.addingTimeInterval(60),
              expiresAt > date,
              expiresAt.timeIntervalSince(issuedAt) <= maximumDuration + 1 else {
            lock(url: url)
            return nil
        }
        return SharedUnlockSessionStatus(
            id: payload.id,
            issuedAt: issuedAt,
            expiresAt: expiresAt
        )
    }

    public static func isUnlocked(
        at date: Date = Date(),
        url: URL = defaultURL(),
        authenticationKey: SymmetricKey? = nil
    ) -> Bool {
        status(at: date, url: url, authenticationKey: authenticationKey) != nil
    }

    public static func lock(url: URL = defaultURL()) {
        try? FileManager.default.removeItem(at: url)
    }

    private static func isPrivateRegularFile(_ url: URL) -> Bool {
        guard let values = try? url.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey]),
              values.isRegularFile == true,
              values.isSymbolicLink != true,
              let attributes = try? FileManager.default.attributesOfItem(atPath: url.path),
              let owner = attributes[.ownerAccountID] as? NSNumber,
              owner.uint32Value == geteuid(),
              let permissions = attributes[.posixPermissions] as? NSNumber,
              permissions.intValue & 0o077 == 0 else {
            return false
        }
        return true
    }

    private static func authenticationMessage(
        version: Int,
        id: UUID,
        issuedAt: Int64,
        expiresAt: Int64
    ) -> Data {
        Data("\(version)\n\(id.uuidString.lowercased())\n\(issuedAt)\n\(expiresAt)".utf8)
    }

    private static func defaultAuthenticationKey(for url: URL) throws -> SymmetricKey {
        let directory = url.deletingLastPathComponent()
        let leaf = directory.standardizedFileURL.lastPathComponent
        let account = leaf == "vibe-vault"
            ? KeychainMasterKey.defaultAccount
            : "vault.master.\(leaf)"
        let cacheID = "\(directory.standardizedFileURL.path)|\(account)"
        if let cached = keyQueue.sync(execute: { cachedKeys[cacheID] }) {
            return cached
        }
        let key = try VaultFileCrypto.loadOrCreateKey(
            legacyFileURL: directory.appendingPathComponent("master.key"),
            account: account
        )
        keyQueue.sync { cachedKeys[cacheID] = key }
        return key
    }
}
