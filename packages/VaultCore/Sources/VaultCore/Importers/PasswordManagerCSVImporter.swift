import Foundation

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
        let totpAuthURL = normalizedTOTP(
            firstValue(fields, [
                "otpauth", "otp auth", "login_totp", "login totp", "totp", "otp", "one-time password"
            ]),
            title: title,
            issuer: profile.label
        )
        return VaultService.ImportItem(
            name: vaultName(from: title),
            value: password,
            notes: totpAuthURL == nil ? notes : "\(notes) · MFA code included",
            totpAuthURL: totpAuthURL
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

    private static func normalizedTOTP(_ value: String?, title: String, issuer: String) -> String? {
        guard let value = value?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty else {
            return nil
        }
        return try? TOTPGenerator.normalizedAuthURL(from: value, label: title, issuer: issuer)
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
