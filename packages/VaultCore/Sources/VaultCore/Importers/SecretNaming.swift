import Foundation

public enum SecretNaming {
  /// Default vault prefix from a project folder, e.g. `my-worker_`.
    public static func defaultProjectPrefix(from projectURL: URL) -> String {
        let raw = projectURL.lastPathComponent.trimmingCharacters(in: .whitespacesAndNewlines)
        let sanitized = sanitizePrefix(raw)
        return sanitized.isEmpty ? "" : "\(sanitized)_"
    }

    public static func sanitizePrefix(_ raw: String) -> String {
        let normalized = raw
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .uppercased()
            .replacingOccurrences(of: "-", with: "_")
            .replacingOccurrences(of: ".", with: "_")
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "_"))
        let scalars = normalized.unicodeScalars.filter { allowed.contains($0) }
        return String(String.UnicodeScalarView(scalars))
    }

    public static func applyPrefix(_ prefix: String, to secretName: String) -> String {
        let p = sanitizePrefix(prefix)
        guard !p.isEmpty else { return secretName }
        let sep = p.hasSuffix("_") ? "" : "_"
        return "\(p)\(sep)\(secretName)"
    }

    public static func maskedValue(_ value: String) -> String {
        guard value.count > 8 else { return String(repeating: "•", count: max(value.count, 4)) }
        return "\(value.prefix(3))…\(value.suffix(4))"
    }

    /// Vault names cannot contain spaces, so Finder-style " - copy" becomes `-copy`.
    public static func copyName(of name: String, taken: Set<String>) -> String {
        let candidate = "\(name)-copy"
        if !taken.contains(candidate) { return candidate }
        var index = 2
        while taken.contains("\(name)-copy-\(index)") {
            index += 1
        }
        return "\(name)-copy-\(index)"
    }
}
