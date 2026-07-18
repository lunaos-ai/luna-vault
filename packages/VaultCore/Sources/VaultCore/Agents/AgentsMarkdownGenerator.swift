import Foundation

/// Writes a short `AGENTS.md` section so Cursor picks up vault workflow per repo.
public enum AgentsMarkdownGenerator {
    public static let marker = "<!-- vibe-vault -->"
    public static let fileName = "AGENTS.md"

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

        - Use the `vibe-vault` MCP server. Never ask the user to paste secret values in chat.
        - Required: \(requiredLine)
        - Missing from vault: \(missingLine)
        - Do not commit `.env` / `.env.*` (except `.env.example`). Prefer `vibevault cursor prepare`.
        - Allow AI access per secret in Vibe Vault before calling `read_secret`.

        """
    }

    public static func install(projectURL: URL, scan: ScanResult?) throws -> Bool {
        let url = projectURL.appendingPathComponent(fileName)
        let body = generate(scan: scan, projectName: projectURL.lastPathComponent)
        if let existing = try? String(contentsOf: url, encoding: .utf8),
           existing.contains(marker) {
            let stripped = stripMarkedSection(existing)
            let next = stripped.trimmingCharacters(in: .whitespacesAndNewlines)
                + "\n\n" + body
            try next.write(to: url, atomically: true, encoding: .utf8)
            return true
        }
        if let existing = try? String(contentsOf: url, encoding: .utf8) {
            let next = existing.trimmingCharacters(in: .whitespacesAndNewlines)
                + "\n\n" + body
            try next.write(to: url, atomically: true, encoding: .utf8)
            return true
        }
        try body.write(to: url, atomically: true, encoding: .utf8)
        return true
    }

    public static func stripMarkedSection(_ text: String) -> String {
        guard let start = text.range(of: marker) else { return text }
        return String(text[..<start.lowerBound])
    }
}
