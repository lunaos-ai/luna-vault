import Foundation

public struct NextConfigParser: SecretFileParser {
    public let filename = "next.config.js"
    public init() {}

    public func parse(content: String) -> [String] {
        var out = Set<String>()
        extractProcessEnv(content, into: &out)
        extractEnvBlock(content, into: &out)
        return Array(out)
    }

    private func extractProcessEnv(_ text: String, into out: inout Set<String>) {
        let pattern = "process\\.env\\.([A-Z_][A-Z0-9_]+)"
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return }
        let ns = text as NSString
        regex.enumerateMatches(in: text, range: NSRange(location: 0, length: ns.length)) { m, _, _ in
            guard let m = m, m.numberOfRanges > 1 else { return }
            out.insert(ns.substring(with: m.range(at: 1)))
        }
    }

    private func extractEnvBlock(_ text: String, into out: inout Set<String>) {
        // Best-effort: find `env: { KEY: ..., }` blocks
        guard let envRange = text.range(of: "env:") else { return }
        let after = text[envRange.upperBound...]
        guard let openBrace = after.firstIndex(of: "{") else { return }
        var depth = 0
        var current = openBrace
        var endIdx: String.Index?
        var idx = openBrace
        while idx < after.endIndex {
            let c = after[idx]
            if c == "{" { depth += 1 }
            else if c == "}" { depth -= 1; if depth == 0 { endIdx = idx; break } }
            idx = after.index(after: idx)
            _ = current
            current = idx
        }
        guard let end = endIdx else { return }
        let block = String(after[openBrace...end])
        let pattern = "([A-Z_][A-Z0-9_]+)\\s*:"
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return }
        let ns = block as NSString
        regex.enumerateMatches(in: block, range: NSRange(location: 0, length: ns.length)) { m, _, _ in
            guard let m = m, m.numberOfRanges > 1 else { return }
            out.insert(ns.substring(with: m.range(at: 1)))
        }
    }
}
