import Foundation

public struct MCPSandboxToken: Equatable, Sendable {
    public let value: String
    public let expiresAt: Date

    public init(value: String, expiresAt: Date) {
        self.value = value
        self.expiresAt = expiresAt
    }
}

enum MCPSandboxSigningKey {
    static let prefsKey = "mcp.sandbox.token.signing-key"

    static func loadOrCreate(prefs: PreferenceStoring) throws -> SymmetricKey {
        if let data = prefs.data(forKey: prefsKey), data.count == 32 {
            return SymmetricKey(data: data)
        }
        let key = try PlatformRandom.symmetricKey()
        prefs.set(key.withUnsafeBytes { Data($0) }, forKey: prefsKey)
        return key
    }

    static func rotate(prefs: PreferenceStoring) throws {
        prefs.set(nil, forKey: prefsKey)
        _ = try loadOrCreate(prefs: prefs)
    }
}

public enum MCPSandboxTokenMint {
    public static func mint(
        minutes: Int,
        prefs: PreferenceStoring,
        now: Date = Date()
    ) throws -> MCPSandboxToken {
        let bounded = min(max(minutes, 5), 480)
        let expiresAt = now.addingTimeInterval(TimeInterval(bounded * 60))
        let payload = Payload(exp: expiresAt.timeIntervalSince1970, n: UUID().uuidString)
        let payloadData = try JSONEncoder().encode(payload)
        let key = try MCPSandboxSigningKey.loadOrCreate(prefs: prefs)
        let mac = Data(HMAC<SHA256>.authenticationCode(for: payloadData, using: key))
        let value = "vv1." + Base64URL.encode(payloadData) + "." + Base64URL.encode(mac)
        return MCPSandboxToken(value: value, expiresAt: expiresAt)
    }

    public static func validate(
        _ token: String,
        prefs: PreferenceStoring,
        now: Date = Date()
    ) -> Bool {
        let parts = token.split(separator: ".", omittingEmptySubsequences: false).map(String.init)
        guard parts.count == 3, parts[0] == "vv1",
              let payloadData = Base64URL.decode(parts[1]),
              let mac = Base64URL.decode(parts[2]),
              let payload = try? JSONDecoder().decode(Payload.self, from: payloadData),
              let keyData = prefs.data(forKey: MCPSandboxSigningKey.prefsKey),
              keyData.count == 32
        else { return false }
        let key = SymmetricKey(data: keyData)
        let expected = Data(HMAC<SHA256>.authenticationCode(for: payloadData, using: key))
        guard ConstantTime.equals(mac, expected) else { return false }
        return payload.exp > now.timeIntervalSince1970
    }

    private struct Payload: Codable {
        let exp: TimeInterval
        let n: String
    }
}

enum Base64URL {
    static func encode(_ data: Data) -> String {
        data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    static func decode(_ string: String) -> Data? {
        var padded = string
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        while padded.count % 4 != 0 { padded.append("=") }
        return Data(base64Encoded: padded)
    }
}
