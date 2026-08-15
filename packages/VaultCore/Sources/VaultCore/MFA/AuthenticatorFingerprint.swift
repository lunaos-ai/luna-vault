import CryptoKit
import Foundation

extension AuthenticatorAccount {
    func seedFingerprint(using key: SymmetricKey) -> Data {
        var canonical = Data()
        canonical.append(secret)
        canonical.append(0)
        canonical.append(contentsOf: algorithm.rawValue.utf8)
        canonical.append(0)
        canonical.append(contentsOf: String(digits).utf8)
        canonical.append(0)
        canonical.append(contentsOf: String(period).utf8)
        return Data(HMAC<SHA256>.authenticationCode(for: canonical, using: key))
    }
}
