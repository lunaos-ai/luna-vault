import CryptoKit
import Foundation

/// Embedded Ed25519 public key (32 bytes, base64). Rotate by regenerating the keypair.
public enum LicensePublicKey {
    public static let base64 = "ZNyv9z4uUGEFjM+l1V9qjmGh+iJ43+YQ49e25f0pHt0="

    public static func curveKey() throws -> Curve25519.Signing.PublicKey {
        guard let data = Data(base64Encoded: base64), data.count == 32 else {
            throw LicenseError.decodeFailed
        }
        return try Curve25519.Signing.PublicKey(rawRepresentation: data)
    }
}
