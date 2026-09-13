import Foundation

/// Enrolled user passkey for sandbox MCP. Stored as PBKDF2-SHA256 (salt + hash), never plaintext.
public struct MCPSandboxPasskeyStore: Sendable {
    public enum Keys {
        public static let salt = "mcp.sandbox.passkey.salt"
        public static let hash = "mcp.sandbox.passkey.hash"
        public static let iterations = "mcp.sandbox.passkey.iterations"
    }

    private let prefs: PreferenceStoring

    public init(prefs: PreferenceStoring) {
        self.prefs = prefs
    }

    public var isEnrolled: Bool {
        prefs.data(forKey: Keys.salt) != nil && prefs.data(forKey: Keys.hash) != nil
    }

    public func enroll(_ passkey: String) throws {
        let trimmed = passkey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= MCPSandboxSettings.minPasskeyLength else {
            throw MCPSandboxError.passkeyTooShort
        }
        let salt = Data(try PlatformRandom.bytes(count: 16))
        let iterations = MCPSandboxSettings.pbkdf2Iterations
        let hash = try derive(trimmed, salt: salt, iterations: iterations)
        prefs.set(salt, forKey: Keys.salt)
        prefs.set(hash, forKey: Keys.hash)
        prefs.setCodable(iterations, forKey: Keys.iterations)
        try MCPSandboxSigningKey.rotate(prefs: prefs)
    }

    public func verify(_ passkey: String) throws -> Bool {
        guard let salt = prefs.data(forKey: Keys.salt),
              let stored = prefs.data(forKey: Keys.hash) else {
            throw MCPSandboxError.passkeyNotEnrolled
        }
        let iterations = prefs.codable(Int.self, forKey: Keys.iterations)
            ?? MCPSandboxSettings.pbkdf2Iterations
        let derived = try derive(passkey, salt: salt, iterations: iterations)
        return ConstantTime.equals(derived, stored)
    }

    public func clear() {
        prefs.set(nil, forKey: Keys.salt)
        prefs.set(nil, forKey: Keys.hash)
        prefs.set(nil, forKey: Keys.iterations)
        prefs.set(nil, forKey: MCPSandboxSigningKey.prefsKey)
    }

    private func derive(_ passkey: String, salt: Data, iterations: Int) throws -> Data {
        do {
            return try PlatformPBKDF2.derive(
                passphrase: passkey,
                salt: salt,
                iterations: iterations
            )
        } catch {
            throw MCPSandboxError.keyDerivationFailed
        }
    }
}

enum ConstantTime {
    static func equals(_ lhs: Data, _ rhs: Data) -> Bool {
        guard lhs.count == rhs.count else { return false }
        var diff: UInt8 = 0
        for (a, b) in zip(lhs, rhs) { diff |= a ^ b }
        return diff == 0
    }
}
