import Foundation

enum LinuxMasterKeyHex {
    static func encode(_ data: Data) -> String {
        data.map { String(format: "%02x", $0) }.joined()
    }

    static func decode(_ hex: String) throws -> Data {
        let trimmed = hex.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard trimmed.count.isMultiple(of: 2), !trimmed.isEmpty else {
            throw SecretError.vaultIO("corrupt libsecret master key")
        }
        var data = Data()
        data.reserveCapacity(trimmed.count / 2)
        var index = trimmed.startIndex
        while index < trimmed.endIndex {
            let next = trimmed.index(index, offsetBy: 2)
            let byte = trimmed[index..<next]
            guard let value = UInt8(byte, radix: 16) else {
                throw SecretError.vaultIO("corrupt libsecret master key")
            }
            data.append(value)
            index = next
        }
        return data
    }
}
