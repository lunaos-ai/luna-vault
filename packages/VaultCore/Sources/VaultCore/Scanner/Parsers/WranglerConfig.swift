import Foundation

public struct WranglerConfig: Equatable, Sendable {
    public static let candidateFilenames = ["wrangler.toml", "wrangler.jsonc", "wrangler.json"]

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
        for filename in candidateFilenames {
            let url = projectURL.appendingPathComponent(filename)
            guard let content = try? String(contentsOf: url, encoding: .utf8) else { continue }
            return parse(content: content, filename: filename)
        }
        return WranglerConfig(scriptName: nil, accountId: nil)
    }

    public static func parse(content: String, filename: String = "wrangler.toml") -> WranglerConfig {
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        if filename.hasSuffix(".json") || filename.hasSuffix(".jsonc") || trimmed.hasPrefix("{") {
            return parseJSON(content: content)
        }
        return parseTOML(content: content)
    }

    static func jsonObject(content: String) -> [String: Any]? {
        let stripped = stripTrailingCommas(stripJSONCComments(content))
        guard let data = stripped.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return nil }
        return json
    }

    private static func parseJSON(content: String) -> WranglerConfig {
        guard let json = jsonObject(content: content) else {
            return WranglerConfig(scriptName: nil, accountId: nil)
        }
        let scriptName = stringValue(json["name"])
        let accountId = stringValue(json["account_id"])
        return WranglerConfig(scriptName: scriptName, accountId: accountId)
    }

    private static func parseTOML(content: String) -> WranglerConfig {
        var scriptName: String?
        var accountId: String?
        var table: String?
        for raw in content.components(separatedBy: .newlines) {
            let line = stripTOMLComment(raw).trimmingCharacters(in: .whitespaces)
            if line.hasPrefix("#") { continue }
            if line.hasPrefix("[") && line.hasSuffix("]") {
                table = line
                continue
            }
            guard table == nil else { continue }
            if tomlKey(line) == "name", scriptName == nil {
                scriptName = tomlValue(line)
            }
            if tomlKey(line) == "account_id", accountId == nil {
                accountId = tomlValue(line)
            }
        }
        return WranglerConfig(scriptName: scriptName, accountId: accountId)
    }

    static func stripTOMLComment(_ line: String) -> String {
        var output = ""
        var quote: Character?
        var escaped = false
        for ch in line {
            if let active = quote {
                output.append(ch)
                if escaped {
                    escaped = false
                } else if ch == "\\" {
                    escaped = true
                } else if ch == active {
                    quote = nil
                }
                continue
            }
            if ch == "\"" || ch == "'" {
                quote = ch
                output.append(ch)
            } else if ch == "#" {
                break
            } else {
                output.append(ch)
            }
        }
        return output
    }

    private static func stripJSONCComments(_ content: String) -> String {
        var output = ""
        var index = content.startIndex
        var inString = false
        var escaped = false
        while index < content.endIndex {
            let ch = content[index]
            let next = content.index(after: index)
            if inString {
                output.append(ch)
                if escaped {
                    escaped = false
                } else if ch == "\\" {
                    escaped = true
                } else if ch == "\"" {
                    inString = false
                }
                index = next
                continue
            }
            if ch == "\"" {
                inString = true
                output.append(ch)
                index = next
                continue
            }
            if ch == "/", next < content.endIndex {
                let peek = content[next]
                if peek == "/" {
                    index = content.index(after: next)
                    while index < content.endIndex, content[index] != "\n" {
                        index = content.index(after: index)
                    }
                    if index < content.endIndex { output.append("\n") }
                    continue
                }
                if peek == "*" {
                    index = content.index(after: next)
                    while index < content.endIndex {
                        let current = content[index]
                        let afterCurrent = content.index(after: index)
                        if current == "*", afterCurrent < content.endIndex, content[afterCurrent] == "/" {
                            index = content.index(after: afterCurrent)
                            break
                        }
                        if current == "\n" { output.append("\n") }
                        index = afterCurrent
                    }
                    continue
                }
            }
            output.append(ch)
            index = next
        }
        return output
    }

    private static func stripTrailingCommas(_ content: String) -> String {
        var output = ""
        var index = content.startIndex
        var inString = false
        var escaped = false
        while index < content.endIndex {
            let ch = content[index]
            let next = content.index(after: index)
            if inString {
                output.append(ch)
                if escaped {
                    escaped = false
                } else if ch == "\\" {
                    escaped = true
                } else if ch == "\"" {
                    inString = false
                }
                index = next
                continue
            }
            if ch == "\"" {
                inString = true
                output.append(ch)
                index = next
                continue
            }
            if ch == "," {
                var lookahead = next
                while lookahead < content.endIndex, content[lookahead].isWhitespace {
                    lookahead = content.index(after: lookahead)
                }
                if lookahead < content.endIndex, content[lookahead] == "}" || content[lookahead] == "]" {
                    index = next
                    continue
                }
            }
            output.append(ch)
            index = next
        }
        return output
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

    private static func tomlKey(_ line: String) -> String? {
        guard let eq = line.firstIndex(of: "=") else { return nil }
        return String(line[..<eq]).trimmingCharacters(in: .whitespaces)
    }

    private static func stringValue(_ value: Any?) -> String? {
        if let value = value as? String {
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? nil : trimmed
        }
        if let value = value as? NSNumber {
            return value.stringValue
        }
        return nil
    }
}
