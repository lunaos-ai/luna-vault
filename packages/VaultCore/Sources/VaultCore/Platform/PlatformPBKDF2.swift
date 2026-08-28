import Foundation

enum PlatformPBKDF2 {
    static func derive(
        passphrase: String,
        salt: Data,
        iterations: Int,
        byteCount: Int = 32
    ) throws -> Data {
        let password = Data(passphrase.utf8)
        #if canImport(CommonCrypto)
        var stretched = Data(count: byteCount)
        let status = stretched.withUnsafeMutableBytes { stretchedBytes in
            salt.withUnsafeBytes { saltBytes in
                CCKeyDerivationPBKDF(
                    CCPBKDFAlgorithm(kCCPBKDF2),
                    passphrase, passphrase.utf8.count,
                    saltBytes.bindMemory(to: UInt8.self).baseAddress, salt.count,
                    CCPseudoRandomAlgorithm(kCCPRFHmacAlgSHA256),
                    UInt32(iterations),
                    stretchedBytes.bindMemory(to: UInt8.self).baseAddress, byteCount
                )
            }
        }
        guard status == kCCSuccess else {
            throw CloudSyncError.keyDerivationFailed
        }
        return stretched
        #else
        return deriveHMAC(password: password, salt: salt, iterations: iterations, byteCount: byteCount)
        #endif
    }

    #if !canImport(CommonCrypto)
    private static func deriveHMAC(
        password: Data,
        salt: Data,
        iterations: Int,
        byteCount: Int
    ) -> Data {
        let blocks = (byteCount + 31) / 32
        var output = Data()
        for block in 1...blocks {
            output.append(pbkdf2Block(password: password, salt: salt, iterations: iterations, block: block))
        }
        return Data(output.prefix(byteCount))
    }

    private static func pbkdf2Block(
        password: Data,
        salt: Data,
        iterations: Int,
        block: Int
    ) -> Data {
        var saltBlock = salt
        saltBlock.append(contentsOf: [
            UInt8((block >> 24) & 0xff),
            UInt8((block >> 16) & 0xff),
            UInt8((block >> 8) & 0xff),
            UInt8(block & 0xff),
        ])
        let key = SymmetricKey(data: password)
        var u = Data(HMAC<SHA256>.authenticationCode(for: saltBlock, using: key))
        var result = u
        if iterations > 1 {
            for _ in 1..<iterations {
                u = Data(HMAC<SHA256>.authenticationCode(for: u, using: key))
                result = xor(result, u)
            }
        }
        return result
    }

    private static func xor(_ lhs: Data, _ rhs: Data) -> Data {
        Data(zip(lhs, rhs).map { $0 ^ $1 })
    }
    #endif
}

#if canImport(CommonCrypto)
import CommonCrypto
#endif
