import Foundation

public struct VercelParser: SecretFileParser {
    public let filename = "vercel.json"
    public init() {}

    public func parse(content: String) -> [String] {
        guard let data = content.data(using: .utf8),
              let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return [] }
        var out = Set<String>()
        collectEnvKeys(from: root, into: &out)
        collectSecretReferences(in: content, into: &out)
        return Array(out)
    }

    private func collectEnvKeys(from object: Any, into out: inout Set<String>) {
        if let dict = object as? [String: Any] {
            if let envDict = dict["env"] as? [String: Any] {
                for key in envDict.keys { out.insert(key) }
            }
            if let buildEnv = dict["build"] as? [String: Any], let envDict = buildEnv["env"] as? [String: Any] {
                for key in envDict.keys { out.insert(key) }
            }
            for (_, v) in dict { collectEnvKeys(from: v, into: &out) }
        } else if let arr = object as? [Any] {
            for v in arr { collectEnvKeys(from: v, into: &out) }
        }
    }

    private func collectSecretReferences(in raw: String, into out: inout Set<String>) {
        // matches "@secret-name" or "@SECRET_NAME" references
        let pattern = "@([A-Za-z_][A-Za-z0-9_-]+)"
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return }
        let ns = raw as NSString
        regex.enumerateMatches(in: raw, range: NSRange(location: 0, length: ns.length)) { m, _, _ in
            guard let m = m, m.numberOfRanges > 1 else { return }
            let name = ns.substring(with: m.range(at: 1))
                .replacingOccurrences(of: "-", with: "_")
                .uppercased()
            out.insert(name)
        }
    }
}
