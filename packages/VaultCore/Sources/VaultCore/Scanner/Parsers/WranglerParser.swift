import Foundation

public struct WranglerParser: SecretFileParser {
    public let filename = "wrangler.toml"
    public init() {}

    public func parse(content: String) -> [String] {
        var out: [String] = []
        var inVars = false
        for rawLine in content.split(whereSeparator: { $0 == "\n" || $0 == "\r" }) {
            let line = String(rawLine).trimmingCharacters(in: .whitespaces)
            if line.hasPrefix("#") { continue }
            if line.hasPrefix("[vars]") || line.hasPrefix("[env.") && line.contains(".vars]") {
                inVars = true
                continue
            }
            if line.hasPrefix("[") && line.hasSuffix("]") { inVars = false; continue }
            if inVars, let eq = line.firstIndex(of: "=") {
                let name = String(line[..<eq]).trimmingCharacters(in: .whitespaces)
                if !name.isEmpty { out.append(name) }
            }
            if let name = matchSecretBinding(line) { out.append(name) }
        }
        return out
    }

    private func matchSecretBinding(_ line: String) -> String? {
        // matches: name = "FOO_BAR"  inside a [[d1_databases]] / secret stanza (best-effort)
        guard line.contains("name") && line.contains("=") else { return nil }
        guard let firstQuote = line.firstIndex(of: "\"") else { return nil }
        let afterFirst = line.index(after: firstQuote)
        guard let secondQuote = line[afterFirst...].firstIndex(of: "\"") else { return nil }
        let value = String(line[afterFirst..<secondQuote])
        if value == value.uppercased() && value.contains("_") { return value }
        return nil
    }
}
