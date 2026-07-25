import Foundation
import Security

public enum CloudRecoveryKey {
    public static let prefix = "VV-RK1"
    public static let preferenceKey = "cloud-backup-recovery-key"
    private static let byteCount = 32

    public static func generate() throws -> String {
        var bytes = [UInt8](repeating: 0, count: byteCount)
        guard SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes) == errSecSuccess else {
            throw CloudSyncError.randomGenerationFailed
        }
        return format(Data(bytes).map { String(format: "%02X", $0) }.joined())
    }

    public static func canonicalize(_ value: String) throws -> String {
        let compact = value
            .uppercased()
            .filter { !$0.isWhitespace && $0 != "-" }
        let payload: String
        if compact.hasPrefix("VVRK1") {
            payload = String(compact.dropFirst(5))
        } else {
            payload = compact
        }
        guard payload.count == byteCount * 2,
              payload.allSatisfy({ $0.isHexDigit }) else {
            throw CloudSyncError.invalidRecoveryKey
        }
        return format(payload)
    }

    static func keyData(_ value: String) throws -> Data {
        let canonical = try canonicalize(value)
        let hex = canonical
            .split(separator: "-")
            .dropFirst(2)
            .joined()
        var result = Data(capacity: byteCount)
        var index = hex.startIndex
        while index < hex.endIndex {
            let next = hex.index(index, offsetBy: 2)
            guard let byte = UInt8(hex[index..<next], radix: 16) else {
                throw CloudSyncError.invalidRecoveryKey
            }
            result.append(byte)
            index = next
        }
        return result
    }

    private static func format(_ payload: String) -> String {
        let groups = stride(from: 0, to: payload.count, by: 4).map { offset -> String in
            let start = payload.index(payload.startIndex, offsetBy: offset)
            let end = payload.index(start, offsetBy: min(4, payload.count - offset))
            return String(payload[start..<end])
        }
        return (["VV", "RK1"] + groups).joined(separator: "-")
    }
}
