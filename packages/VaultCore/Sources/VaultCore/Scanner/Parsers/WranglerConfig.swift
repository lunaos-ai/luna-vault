import Foundation

public struct WranglerConfig: Equatable, Sendable {
    public let scriptName: String?
    public let accountId: String?

    public init(scriptName: String?, accountId: String?) {
        self.scriptName = scriptName
        self.accountId = accountId
    }

    public var scope: [String: String] {
        var out: [String: String] = [:]
        if let scriptName { out["script_name"] = scriptName }
        if let accountId { out["account_id"] = accountId }
        return out
    }

    public var isComplete: Bool { scriptName != nil && accountId != nil }

    public static func load(from projectURL: URL) -> WranglerConfig {
        let url = projectURL.appendingPathComponent("wrangler.toml")
        guard let content = try? String(contentsOf: url, encoding: .utf8) else {
            return WranglerConfig(scriptName: nil, accountId: nil)
        }
        return parse(content: content)
    }

    public static func parse(content: String) -> WranglerConfig {
        var scriptName: String?
        var accountId: String?
        for raw in content.split(whereSeparator: { $0 == "\n" || $0 == "\r" }) {
            let line = String(raw).trimmingCharacters(in: .whitespaces)
            if line.hasPrefix("#") { continue }
            if line.hasPrefix("name"), scriptName == nil {
                scriptName = tomlValue(line)
            }
            if line.hasPrefix("account_id"), accountId == nil {
                accountId = tomlValue(line)
            }
        }
        return WranglerConfig(scriptName: scriptName, accountId: accountId)
    }

    private static func tomlValue(_ line: String) -> String? {
        guard let eq = line.firstIndex(of: "=") else { return nil }
        var value = String(line[line.index(after: eq)...]).trimmingCharacters(in: .whitespaces)
        if value.hasPrefix("\""), value.hasSuffix("\""), value.count >= 2 {
            value = String(value.dropFirst().dropLast())
        } else if value.hasPrefix("'"), value.hasSuffix("'"), value.count >= 2 {
            value = String(value.dropFirst().dropLast())
        }
        return value.isEmpty ? nil : value
    }
}
