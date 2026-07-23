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

public enum PasswordManagerImportProfile: String, CaseIterable, Identifiable, Sendable {
    case auto
    case applePasswords
    case bitwarden
    case onePasswordCSV
    case lastPass
    case dashlane

    public var id: String { rawValue }

    public var label: String {
        switch self {
        case .auto: return "Auto-detect"
        case .applePasswords: return "Apple Passwords"
        case .bitwarden: return "Bitwarden"
        case .onePasswordCSV: return "1Password CSV"
        case .lastPass: return "LastPass"
        case .dashlane: return "Dashlane"
        }
    }
}

public enum PasswordManagerCSVImporter {
    public static func parseFile(at url: URL, profile: PasswordManagerImportProfile = .auto) throws -> [VaultService.ImportItem] {
        guard FileManager.default.fileExists(atPath: url.path) else { throw ImporterError.fileNotFound(url.path) }
        let content = try String(contentsOf: url, encoding: .utf8)
        return parse(content, profile: profile)
    }

    public static func parse(_ content: String, profile: PasswordManagerImportProfile = .auto) -> [VaultService.ImportItem] {
        let rows = parseCSV(content)
        guard let header = rows.first, !header.isEmpty else { return [] }
        let keys = header.map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
        let detected = profile == .auto ? detectProfile(keys: keys) : profile
        return rows.dropFirst().compactMap { row in
            importItem(row: row, keys: keys, profile: detected)
        }
    }

    private static func detectProfile(keys: [String]) -> PasswordManagerImportProfile {
        let set = Set(keys)
        if set.contains("login_password") { return .bitwarden }
        if set.contains("otp auth") || set.contains("otpauth") { return .applePasswords }
        if set.contains("extra") && set.contains("grouping") { return .lastPass }
        if set.contains("title") && set.contains("password") && set.contains("url") { return .dashlane }
        return .onePasswordCSV
    }

    private static func importItem(
        row: [String],
        keys: [String],
        profile: PasswordManagerImportProfile
    ) -> VaultService.ImportItem? {
        let fields = dictionary(row: row, keys: keys)
        let password = firstValue(fields, [
            "password", "login_password", "login password", "pass"
        ])
        guard let password, !password.isEmpty else { return nil }

        let title = firstValue(fields, [
            "title", "name", "login_uri", "url", "website"
        ]) ?? "password"
        let username = firstValue(fields, [
            "username", "login_username", "login username", "email"
        ])
        let url = firstValue(fields, [
            "url", "login_uri", "website", "uri"
        ])
        let notes = importNotes(profile: profile, title: title, username: username, url: url)
        return VaultService.ImportItem(
            name: vaultName(from: title),
            value: password,
            notes: notes
        )
    }

    private static func dictionary(row: [String], keys: [String]) -> [String: String] {
        var fields: [String: String] = [:]
        for (index, key) in keys.enumerated() where index < row.count {
            let value = row[index].trimmingCharacters(in: .whitespacesAndNewlines)
            if !value.isEmpty { fields[key] = value }
        }
        return fields
    }

    private static func firstValue(_ fields: [String: String], _ names: [String]) -> String? {
        for name in names {
            if let value = fields[name], !value.isEmpty { return value }
        }
        return nil
    }

    private static func importNotes(profile: PasswordManagerImportProfile, title: String, username: String?, url: String?) -> String {
        var parts = ["imported from \(profile.label) export", "title: \(title)"]
        if let username, !username.isEmpty { parts.append("username: \(username)") }
        if let url, !url.isEmpty { parts.append("url: \(url)") }
        return parts.joined(separator: " · ")
    }

    private static func vaultName(from title: String) -> String {
        let fallback = title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "PASSWORD" : title
        let separated = fallback.replacingOccurrences(of: #"\s+"#, with: "_", options: .regularExpression)
        let sanitized = SecretNaming.sanitizePrefix(separated)
        let compact = sanitized.isEmpty ? "PASSWORD" : sanitized
        return compact.hasSuffix("_PASSWORD") ? compact : "\(compact)_PASSWORD"
    }

    private static func parseCSV(_ content: String) -> [[String]] {
        var rows: [[String]] = []
        var row: [String] = []
        var field = ""
        var inQuotes = false
        var iterator = content.makeIterator()

        while let char = iterator.next() {
            if inQuotes {
                if char == "\"" {
                    if let next = iterator.next() {
                        if next == "\"" {
                            field.append("\"")
                        } else {
                            inQuotes = false
                            consumeDelimiter(next, row: &row, rows: &rows, field: &field)
                        }
                    } else {
                        inQuotes = false
                    }
                } else {
                    field.append(char)
                }
            } else if char == "\"" {
                inQuotes = true
            } else {
                consumeDelimiter(char, row: &row, rows: &rows, field: &field)
            }
        }

        row.append(field)
        if !row.allSatisfy({ $0.isEmpty }) { rows.append(row) }
        return rows
    }

    private static func consumeDelimiter(
        _ char: Character,
        row: inout [String],
        rows: inout [[String]],
        field: inout String
    ) {
        switch char {
        case ",":
            row.append(field)
            field = ""
        case "\n":
            row.append(field)
            field = ""
            rows.append(row)
            row = []
        case "\r":
            break
        default:
            field.append(char)
        }
    }
}
