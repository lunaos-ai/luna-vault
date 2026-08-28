import Foundation

enum PlatformRandom {
    static func bytes(count: Int) throws -> [UInt8] {
        var bytes = [UInt8](repeating: 0, count: count)
        #if canImport(Security)
        let status = bytes.withUnsafeMutableBytes { buffer in
            SecRandomCopyBytes(kSecRandomDefault, count, buffer.baseAddress!)
        }
        guard status == errSecSuccess else {
            throw SecretError.vaultIO("secure random failed (\(status))")
        }
        #else
        var generator = SystemRandomNumberGenerator()
        for i in 0..<count {
            bytes[i] = UInt8.random(in: .min ... .max, using: &generator)
        }
        #endif
        return bytes
    }

    static func symmetricKey(bitCount: Int = 256) throws -> SymmetricKey {
        let data = Data(try bytes(count: bitCount / 8))
        return SymmetricKey(data: data)
    }
}
