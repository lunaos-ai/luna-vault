import Foundation

public struct PackageJsonParser: SecretFileParser {
    public let filename = "package.json"
    public init() {}

    public func parse(content: String) -> [String] {
        // Pull `process.env.FOO` patterns referenced in `scripts` (heuristic).
        guard let data = content.data(using: .utf8),
              let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return [] }
        var out = Set<String>()
        if let scripts = root["scripts"] as? [String: String] {
            for (_, v) in scripts { extractEnvRefs(from: v, into: &out) }
        }
        return Array(out)
    }

    private func extractEnvRefs(from text: String, into out: inout Set<String>) {
        let patterns = [
            "process\\.env\\.([A-Z_][A-Z0-9_]+)",
            "\\$\\{([A-Z_][A-Z0-9_]+)\\}",
            "\\$([A-Z_][A-Z0-9_]+)"
        ]
        let ns = text as NSString
        for pattern in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern) else { continue }
            regex.enumerateMatches(in: text, range: NSRange(location: 0, length: ns.length)) { m, _, _ in
                guard let m = m, m.numberOfRanges > 1 else { return }
                out.insert(ns.substring(with: m.range(at: 1)))
            }
        }
    }
}
