import CryptoKit
import Foundation

/// Compact license string: `VV1.<base64url JSON>.<base64url Ed25519 sig>`
public enum LicenseCodec {
    public static let prefix = "VV1"

    private static let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        e.outputFormatting = [.sortedKeys]
        return e
    }()

    private static let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()

    public static func sign(
        _ license: TeamLicense,
        privateKey: Curve25519.Signing.PrivateKey
    ) throws -> String {
        let payload = try encoder.encode(license)
        let sig = try privateKey.signature(for: payload)
        return "\(prefix).\(b64url(payload)).\(b64url(sig))"
    }

    public static func verify(
        _ key: String,
        publicKey: Curve25519.Signing.PublicKey? = nil
    ) throws -> TeamLicense {
        let pub = try publicKey ?? LicensePublicKey.curveKey()
        let parts = key.split(separator: ".", omittingEmptySubsequences: false).map(String.init)
        guard parts.count == 3, parts[0] == prefix else { throw LicenseError.invalidFormat }
        guard let payload = b64urlDecode(parts[1]), let sig = b64urlDecode(parts[2]) else {
            throw LicenseError.invalidFormat
        }
        guard pub.isValidSignature(sig, for: payload) else { throw LicenseError.badSignature }
        guard let license = try? decoder.decode(TeamLicense.self, from: payload) else {
            throw LicenseError.decodeFailed
        }
        if license.isExpired { throw LicenseError.expired }
        return license
    }

    public static func privateKey(fromBase64 s: String) throws -> Curve25519.Signing.PrivateKey {
        guard let data = Data(base64Encoded: s), data.count == 32 else {
            throw LicenseError.missingPrivateKey
        }
        return try Curve25519.Signing.PrivateKey(rawRepresentation: data)
    }

    private static func b64url(_ data: Data) -> String {
        data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    private static func b64urlDecode(_ s: String) -> Data? {
        var b64 = s.replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/")
        while b64.count % 4 != 0 { b64.append("=") }
        return Data(base64Encoded: b64)
    }
}
