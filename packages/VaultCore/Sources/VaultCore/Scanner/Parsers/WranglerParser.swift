import Foundation

public struct WranglerParser: SecretFileParser {
    public let filename: String
    public init(filename: String = "wrangler.toml") {
        self.filename = filename
    }

    public func parse(content: String) -> [String] {
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        if filename.hasSuffix(".json") || filename.hasSuffix(".jsonc") || trimmed.hasPrefix("{") {
            return parseJSON(content: content)
        }
        return parseTOML(content: content)
    }

    private func parseTOML(content: String) -> [String] {
        var out: [String] = []
        var inVars = false
        for rawLine in content.components(separatedBy: .newlines) {
            let line = WranglerConfig.stripTOMLComment(rawLine).trimmingCharacters(in: .whitespaces)
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

    private func parseJSON(content: String) -> [String] {
        guard let json = WranglerConfig.jsonObject(content: content) else { return [] }
        var out: [String] = []
        collectWranglerNames(from: json, into: &out)
        return Array(Set(out)).sorted()
    }

    private func collectWranglerNames(from value: Any, into out: inout [String]) {
        if let dict = value as? [String: Any] {
            if let vars = dict["vars"] as? [String: Any] {
                out.append(contentsOf: vars.keys)
            }
            for (key, child) in dict {
                if (key == "binding" || key == "name"), let name = child as? String, isBindingLike(name) {
                    out.append(name)
                } else if key != "vars" {
                    collectWranglerNames(from: child, into: &out)
                }
            }
        } else if let array = value as? [Any] {
            for child in array {
                collectWranglerNames(from: child, into: &out)
            }
        }
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

    private func isBindingLike(_ value: String) -> Bool {
        value == value.uppercased() && value.contains("_")
    }
}
