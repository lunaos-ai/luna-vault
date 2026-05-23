import Foundation
#if canImport(AppKit)
import AppKit
#endif

public enum ImporterError: Error, CustomStringConvertible {
    case fileNotFound(String)
    case opNotInstalled
    case opFailed(String)
    case invalidSource(String)

    public var description: String {
        switch self {
        case .fileNotFound(let p): return "file not found: \(p)"
        case .opNotInstalled: return "1Password CLI (`op`) is not installed; brew install 1password-cli"
        case .opFailed(let m): return "1Password CLI failed: \(m)"
        case .invalidSource(let m): return "invalid import source: \(m)"
        }
    }
}

public enum DotenvImporter {
    public static func parse(_ content: String) -> [VaultService.ImportItem] {
        var out: [VaultService.ImportItem] = []
        for rawLine in content.split(whereSeparator: { $0 == "\n" || $0 == "\r" }) {
            let line = String(rawLine).trimmingCharacters(in: .whitespaces)
            if line.isEmpty || line.hasPrefix("#") { continue }
            let trimmed = line.hasPrefix("export ") ? String(line.dropFirst("export ".count)) : line
            guard let eq = trimmed.firstIndex(of: "=") else { continue }
            let name = String(trimmed[..<eq]).trimmingCharacters(in: .whitespaces)
            var value = String(trimmed[trimmed.index(after: eq)...]).trimmingCharacters(in: .whitespaces)
            if let comment = value.range(of: " #") { value = String(value[..<comment.lowerBound]).trimmingCharacters(in: .whitespaces) }
            value = unquote(value)
            if !name.isEmpty, !value.isEmpty {
                out.append(VaultService.ImportItem(name: name, value: value))
            }
        }
        return out
    }

    public static func parseFile(at url: URL) throws -> [VaultService.ImportItem] {
        guard FileManager.default.fileExists(atPath: url.path) else { throw ImporterError.fileNotFound(url.path) }
        let content = try String(contentsOf: url, encoding: .utf8)
        return parse(content)
    }

    private static func unquote(_ s: String) -> String {
        if s.count >= 2, (s.first == "\"" && s.last == "\"") || (s.first == "'" && s.last == "'") {
            return String(s.dropFirst().dropLast())
        }
        return s
    }
}

public enum EnvImporter {
    public static func collect(env: [String: String] = ProcessInfo.processInfo.environment, matching globs: [String]) -> [VaultService.ImportItem] {
        let patterns = globs.map { regexFromGlob($0) }
        let banned: Set<String> = ["PATH", "HOME", "USER", "SHELL", "PWD", "TMPDIR", "LANG", "TERM", "LOGNAME", "SHLVL", "OLDPWD"]
        return env.compactMap { (k, v) -> VaultService.ImportItem? in
            guard !banned.contains(k), !v.isEmpty else { return nil }
            for re in patterns where re.firstMatch(in: k, range: NSRange(0..<k.utf16.count)) != nil {
                return VaultService.ImportItem(name: k, value: v, notes: "imported from env")
            }
            return nil
        }
    }

    private static func regexFromGlob(_ glob: String) -> NSRegularExpression {
        var pattern = "^"
        for ch in glob {
            switch ch {
            case "*": pattern += ".*"
            case "?": pattern += "."
            case ".", "(", ")", "+", "|", "^", "$", "{", "}", "[", "]", "\\": pattern += "\\\(ch)"
            default: pattern += String(ch)
            }
        }
        pattern += "$"
        return (try? NSRegularExpression(pattern: pattern)) ?? NSRegularExpression()
    }
}

public enum ClipboardImporter {
    public static func read() -> [VaultService.ImportItem] {
        #if canImport(AppKit)
        guard let content = NSPasteboard.general.string(forType: .string), !content.isEmpty else { return [] }
        return DotenvImporter.parse(content)
        #else
        return []
        #endif
    }
}

public enum SystemKeychainImporter {
    public static func scan() throws -> [VaultService.ImportItem] {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/security")
        process.arguments = ["dump-keychain", "-d"]
        let stdout = Pipe()
        process.standardOutput = stdout
        process.standardError = Pipe()
        try? process.run()
        process.waitUntilExit()
        let data = stdout.fileHandleForReading.readDataToEndOfFile()
        guard let text = String(data: data, encoding: .utf8) else { return [] }
        var names = Set<String>()
        for line in text.split(separator: "\n") where line.contains("\"acct\"<blob>=\"") {
            if let start = line.range(of: "=\""),
               let end = line.range(of: "\"", range: start.upperBound..<line.endIndex) {
                let name = String(line[start.upperBound..<end.lowerBound])
                let upper = name.uppercased()
                if upper == name && name.contains("_") && name.count <= 64 {
                    names.insert(name)
                }
            }
        }
        return names.map {
            VaultService.ImportItem(
                name: $0,
                value: "(not imported; revisit with explicit value)",
                notes: "discovered in system Keychain"
            )
        }
    }
}

public enum OnePasswordImporter {
    public static func fetch(itemRef: String) throws -> [VaultService.ImportItem] {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = ["op", "item", "get", itemRef, "--format", "json"]
        let stdout = Pipe()
        let stderr = Pipe()
        process.standardOutput = stdout
        process.standardError = stderr
        do { try process.run() }
        catch { throw ImporterError.opNotInstalled }
        process.waitUntilExit()
        if process.terminationStatus != 0 {
            let err = String(data: stderr.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? "unknown"
            throw ImporterError.opFailed(err.trimmingCharacters(in: .whitespacesAndNewlines))
        }
        let data = stdout.fileHandleForReading.readDataToEndOfFile()
        return parse(data: data, itemRef: itemRef)
    }

    static func parse(data: Data, itemRef: String) -> [VaultService.ImportItem] {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let fields = json["fields"] as? [[String: Any]] else { return [] }
        var out: [VaultService.ImportItem] = []
        for field in fields {
            guard let label = field["label"] as? String ?? field["id"] as? String,
                  let value = field["value"] as? String, !value.isEmpty else { continue }
            let purposes: Set<String> = ["PASSWORD", "NOTES"]
            let purpose = field["purpose"] as? String ?? ""
            if purpose == "NOTES" { continue }
            let normalized = label.replacingOccurrences(of: " ", with: "_").uppercased()
            if normalized.isEmpty || normalized == "USERNAME" || normalized == "NOTESPLAIN" { continue }
            _ = purposes
            out.append(VaultService.ImportItem(name: normalized, value: value, notes: "imported from 1Password: \(itemRef)"))
        }
        return out
    }
}
