import Foundation
import VaultCore

struct MCPToolDef {
    let name: String
    let description: String
    let inputSchema: [String: Any]
}

struct MCPContext {
    let service: VaultService
    var clientName: String
}

enum MCPTools {
    static let definitions: [MCPToolDef] = [
        MCPToolDef(
            name: "list_secrets",
            description: "List all secret names in the user's vault. Values are never returned by this tool.",
            inputSchema: ["type": "object", "properties": [:] as [String: Any]]
        ),
        MCPToolDef(
            name: "read_secret",
            description: "Read the value of a single secret. Refuses if the user has not marked the secret as MCP-accessible.",
            inputSchema: [
                "type": "object",
                "properties": ["name": ["type": "string", "description": "Secret name."]],
                "required": ["name"]
            ]
        ),
        MCPToolDef(
            name: "scan_project",
            description: "Scan a project directory for required secrets (wrangler.toml, vercel.json, .env.example, package.json, next.config.js).",
            inputSchema: [
                "type": "object",
                "properties": ["path": ["type": "string", "description": "Absolute path to project root."]],
                "required": ["path"]
            ]
        ),
        MCPToolDef(
            name: "get_audit_log",
            description: "Return recent audit log entries (most recent first). Optional filters: agent, secret, limit.",
            inputSchema: [
                "type": "object",
                "properties": [
                    "agent": ["type": "string"],
                    "secret": ["type": "string"],
                    "limit": ["type": "integer", "default": 50]
                ]
            ]
        )
    ]

    static func call(name: String, arguments: [String: Any], context: MCPContext) async -> [String: Any] {
        do {
            switch name {
            case "list_secrets": return try await listSecrets(context: context)
            case "read_secret": return try await readSecret(args: arguments, context: context)
            case "scan_project": return try scanProject(args: arguments, context: context)
            case "get_audit_log": return try getAuditLog(args: arguments, context: context)
            default: return errorResult("Unknown tool: \(name)")
            }
        } catch {
            return errorResult("\(error)")
        }
    }

    static func listSecrets(context: MCPContext) async throws -> [String: Any] {
        let secrets = try context.service.list().sorted { $0.name < $1.name }
        let lines = secrets.map { secret -> String in
            var bits = [secret.name]
            if secret.mcpAllowed { bits.append("[mcp]") }
            if secret.isExpired { bits.append("[expired]") }
            if secret.isRotationDue { bits.append("[rotate-due]") }
            return bits.joined(separator: " ")
        }
        let body = lines.isEmpty ? "(vault is empty)" : lines.joined(separator: "\n")
        return textResult(body)
    }

    static func readSecret(args: [String: Any], context: MCPContext) async throws -> [String: Any] {
        guard let name = args["name"] as? String else { return errorResult("missing 'name'") }
        let listEntry = try context.service.list().first { $0.name == name }
        guard let entry = listEntry else { return errorResult("secret '\(name)' not found") }
        if !entry.mcpAllowed {
            try context.service.recordEvent(name: name, action: .read, projectPath: nil)
            return errorResult("secret '\(name)' is not allowed for MCP access. Toggle 'Allow AI agents' in Vibe Vault first.")
        }
        let secret = try await context.service.read(name: name, reason: "MCP read via \(context.clientName)")
        try context.service.recordEvent(name: name, action: .read, projectPath: nil)
        return textResult(secret.value)
    }

    static func scanProject(args: [String: Any], context: MCPContext) throws -> [String: Any] {
        guard let path = args["path"] as? String else { return errorResult("missing 'path'") }
        let url = URL(fileURLWithPath: path)
        let known = Set(try context.service.list().map(\.name))
        let result = try ProjectScanner().scan(projectURL: url, knownSecrets: known)
        var lines: [String] = []
        lines.append("required: \(result.required.count)")
        lines.append("missing: \(Array(result.missing).sorted().joined(separator: ", "))")
        lines.append("extra: \(Array(result.extra).sorted().joined(separator: ", "))")
        for (file, names) in result.sources.sorted(by: { $0.key < $1.key }) {
            lines.append("  \(file): \(names.joined(separator: ", "))")
        }
        return textResult(lines.joined(separator: "\n"))
    }

    static func getAuditLog(args: [String: Any], context: MCPContext) throws -> [String: Any] {
        var filter = AuditFilter(limit: (args["limit"] as? Int) ?? 50)
        if let a = args["agent"] as? String, !a.isEmpty { filter.agent = a }
        if let s = args["secret"] as? String, !s.isEmpty { filter.secretName = s }
        let events = try context.service.audit.query(filter)
        let lines = events.map { e in
            "\(e.timestamp.formatted(date: .abbreviated, time: .shortened)) · \(e.action.rawValue) · \(e.secretName) · \(e.agent) (\(e.agentConfidence.rawValue))"
        }
        return textResult(lines.isEmpty ? "(no events)" : lines.joined(separator: "\n"))
    }

    private static func textResult(_ text: String) -> [String: Any] {
        ["content": [["type": "text", "text": text]]]
    }

    private static func errorResult(_ message: String) -> [String: Any] {
        ["content": [["type": "text", "text": "Error: \(message)"]], "isError": true]
    }
}
