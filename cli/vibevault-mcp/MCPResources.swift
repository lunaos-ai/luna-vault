import Foundation
import VaultCore

struct MCPResourceDef {
    let uri: String
    let name: String
    let description: String
    let mimeType: String
}

enum MCPResources {
    static let definitions: [MCPResourceDef] = [
        MCPResourceDef(
            uri: "vibevault://workflow",
            name: "Vibe Vault workflow",
            description: "Scan → import → MCP allow → provider push",
            mimeType: "text/markdown"
        ),
        MCPResourceDef(
            uri: "vibevault://skill",
            name: "Agent skill",
            description: "SKILL.md content for AI agents",
            mimeType: "text/markdown"
        ),
        MCPResourceDef(
            uri: "vibevault://project-setup",
            name: "Project setup summary",
            description: "Live scan (?path=/abs/root). Use when starting work on a repo.",
            mimeType: "text/markdown"
        )
    ]

    static func list() -> [[String: Any]] {
        definitions.map {
            ["uri": $0.uri, "name": $0.name, "description": $0.description, "mimeType": $0.mimeType]
        }
    }

    static func read(uri: String) -> [String: Any]? {
        let text: String?
        if uri == "vibevault://workflow" {
            text = workflowMarkdown
        } else if uri == "vibevault://skill" {
            text = AgentSkillContent.markdown
        } else if uri.hasPrefix("vibevault://project-setup") {
            text = projectSetupMarkdown(uri: uri)
        } else {
            text = nil
        }
        guard let text else { return nil }
        return ["contents": [["uri": uri, "mimeType": "text/markdown", "text": text]]]
    }

    private static func projectSetupMarkdown(uri: String) -> String {
        let path = queryPath(from: uri)
            ?? ProcessInfo.processInfo.environment["PWD"]
            ?? FileManager.default.currentDirectoryPath
        let url = URL(fileURLWithPath: path)
        do {
            let known = Set((try? VaultService.live().list().map(\.name)) ?? [])
            let result = try ProjectScanner().scan(projectURL: url, knownSecrets: known)
            return formatScan(project: path, result: result)
        } catch {
            return "# Project setup\n\nPath: \(path)\n\nScan failed: \(error)\n"
        }
    }

    private static func queryPath(from uri: String) -> String? {
        guard let q = uri.split(separator: "?").dropFirst().first else { return nil }
        for pair in q.split(separator: "&") {
            let parts = pair.split(separator: "=", maxSplits: 1).map(String.init)
            if parts.count == 2, parts[0] == "path" {
                return parts[1].removingPercentEncoding ?? parts[1]
            }
        }
        return nil
    }

    private static func formatScan(project: String, result: ScanResult) -> String {
        let missing = joinOrNone(Array(result.missing).sorted())
        let extra = joinOrNone(Array(result.extra).sorted())
        var lines = [
            "# Project setup",
            "",
            "Path: `\(project)`",
            "",
            "Required: \(result.required.count)",
            "Missing: \(missing)",
            "Extra in vault: \(extra)",
            ""
        ]
        if !result.gitLeaks.isEmpty {
            lines += [
                "**Git leaks:** \(result.gitLeaks.joined(separator: ", "))",
                "Hint: `vibevault guard install` or Projects → Prepare for Cursor",
                ""
            ]
        }
        lines.append("Next: import missing in Vibe Vault, then enable AI access in the app for agent reads.")
        return lines.joined(separator: "\n")
    }

    private static func joinOrNone(_ items: [String]) -> String {
        items.isEmpty ? "(none)" : items.joined(separator: ", ")
    }

    private static let workflowMarkdown = """
    # Vibe Vault workflow

    1. **Scan** — `scan_project` or resource `vibevault://project-setup?path=…`
    2. **Import** — user imports missing secrets in Vibe Vault app (not in chat)
    3. **Allow** — enable AI access in the Vibe Vault app (agents may only revoke via `set_mcp_allowed`)
    4. **Push** — MCP `push_secrets` or Providers UI
    5. **Audit** — `get_audit_log`

    Never commit `.env`. Never paste secrets into the chat.
    """
}
