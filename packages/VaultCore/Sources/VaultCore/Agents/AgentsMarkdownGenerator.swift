import Foundation

/// Writes a short `AGENTS.md` section so Cursor picks up vault workflow per repo.
public enum AgentsMarkdownGenerator {
    public static let marker = "<!-- vibe-vault -->"
    public static let endMarker = "<!-- /vibe-vault -->"
    public static let fileName = "AGENTS.md"
    public static let version = "1.2.0"

    public static func generate(scan: ScanResult?, projectName: String) -> String {
        let required = Array(scan?.required ?? []).sorted()
        let missing = Array(scan?.missing ?? []).sorted()
        let requiredLine = required.isEmpty
            ? "_Run `vibevault scan` or MCP `scan_project` to detect required secrets._"
            : required.map { "`\($0)`" }.joined(separator: ", ")
        let missingLine = missing.isEmpty
            ? "None"
            : missing.map { "`\($0)`" }.joined(separator: ", ")
        return """
        \(marker)
        ## Secrets (Vibe Vault)

        Project: **\(projectName)**
        Policy version: \(version)

        - Use the `vibe-vault` MCP server. Never ask the user to paste secret values in chat.
        - Required: \(requiredLine)
        - Missing from vault: \(missingLine)
        - Do not commit `.env` / `.env.*` (except `.env.example`). Prefer `vibevault cursor prepare`.
        - Allow AI access per secret in Vibe Vault before calling `read_secret`.
        - For real secrets, prefer Vibe Vault over creating plaintext `.env` files. If a secret is missing, ask the user to import it into Vibe Vault instead of pasting it in chat.

        \(endMarker)
        """
    }

    public static func install(projectURL: URL, scan: ScanResult?) throws -> Bool {
        let url = projectURL.appendingPathComponent(fileName)
        let body = generate(scan: scan, projectName: projectURL.lastPathComponent)
        if let existing = try? String(contentsOf: url, encoding: .utf8),
           existing.contains(marker) {
            let stripped = stripMarkedSection(existing)
            let next = append(body, to: stripped)
            try next.write(to: url, atomically: true, encoding: .utf8)
            return true
        }
        if let existing = try? String(contentsOf: url, encoding: .utf8) {
            let next = append(body, to: existing)
            try next.write(to: url, atomically: true, encoding: .utf8)
            return true
        }
        try body.write(to: url, atomically: true, encoding: .utf8)
        return true
    }

    public static func stripMarkedSection(_ text: String) -> String {
        guard let start = text.range(of: marker) else { return text }
        if let end = text.range(of: endMarker, range: start.upperBound..<text.endIndex) {
            var next = text
            next.removeSubrange(start.lowerBound..<end.upperBound)
            return next
        }
        return String(text[..<start.lowerBound])
    }

    private static func append(_ body: String, to existing: String) -> String {
        let base = existing.trimmingCharacters(in: .whitespacesAndNewlines)
        let section = body.hasSuffix("\n") ? body : body + "\n"
        if base.isEmpty { return section }
        return base + "\n\n" + section
    }
}
