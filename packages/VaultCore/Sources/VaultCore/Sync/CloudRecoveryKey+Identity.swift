import Foundation

extension CloudRecoveryKey {
    /// Full SHA-256 of the canonical recovery-key string, uppercase hex.
    public static func identifier(_ value: String) throws -> String {
        let canonical = try canonicalize(value)
        return SHA256.hash(data: Data(canonical.utf8))
            .map { String(format: "%02X", $0) }
            .joined()
    }

    /// Short display form such as `7F2A-91C4-…-D081`.
    public static func fingerprint(identifier: String) -> String {
        let compact = identifier.uppercased().filter(\.isHexDigit)
        guard compact.count >= 12 else { return compact }
        let head = compact.prefix(4)
        let next = compact.dropFirst(4).prefix(4)
        let tail = compact.suffix(4)
        return "\(head)-\(next)-\u{2026}-\(tail)"
    }

    public static func fingerprint(forKey value: String) throws -> String {
        fingerprint(identifier: try identifier(value))
    }
}
