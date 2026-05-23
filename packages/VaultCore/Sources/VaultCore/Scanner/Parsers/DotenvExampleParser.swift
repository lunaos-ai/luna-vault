import Foundation

public struct DotenvExampleParser: SecretFileParser {
    public let filename = ".env.example"
    public init() {}

    public func parse(content: String) -> [String] {
        var out: [String] = []
        for rawLine in content.split(whereSeparator: { $0 == "\n" || $0 == "\r" }) {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            if line.isEmpty || line.hasPrefix("#") { continue }
            guard let eq = line.firstIndex(of: "=") else { continue }
            let name = String(line[..<eq]).trimmingCharacters(in: .whitespaces)
            if !name.isEmpty { out.append(name) }
        }
        return out
    }
}
