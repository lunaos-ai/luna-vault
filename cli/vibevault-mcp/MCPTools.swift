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
    let prefs: PreferenceStoring
    let registry: ProviderRegistry
}

enum MCPTools {
    static let definitions: [MCPToolDef] = [
        MCPToolDef(
            name: "list_secrets",
            description: "List secret names marked MCP-accessible. Values are never returned.",
            inputSchema: ["type": "object", "properties": [:] as [String: Any]]
        ),
        MCPToolDef(
            name: "read_secret",
            description: "Read a secret value. Only secrets marked MCP-accessible in Vibe Vault.",
            inputSchema: [
                "type": "object",
                "properties": ["name": ["type": "string", "description": "Secret name."]],
                "required": ["name"]
            ]
        ),
        MCPToolDef(
            name: "set_mcp_allowed",
            description: "Allow or revoke MCP access for a vault secret.",
            inputSchema: [
                "type": "object",
                "properties": [
                    "name": ["type": "string"],
                    "allowed": ["type": "boolean"]
                ],
                "required": ["name", "allowed"]
            ]
        ),
        MCPToolDef(
            name: "scan_project",
            description: "Scan a project for required secrets and git-tracked .env leaks.",
            inputSchema: [
                "type": "object",
                "properties": ["path": ["type": "string", "description": "Absolute project root."]],
                "required": ["path"]
            ]
        ),
        MCPToolDef(
            name: "get_audit_log",
            description: "Recent audit entries. Optional filters: agent, secret, limit.",
            inputSchema: [
                "type": "object",
                "properties": [
                    "agent": ["type": "string"],
                    "secret": ["type": "string"],
                    "limit": ["type": "integer", "default": 50]
                ]
            ]
        ),
        MCPToolDef(
            name: "suggest_secrets_for_task",
            description: "Suggest secret names (never values) for a coding task using project scan.",
            inputSchema: [
                "type": "object",
                "properties": [
                    "path": ["type": "string", "description": "Absolute project root."],
                    "task": ["type": "string", "description": "Short task description."]
                ],
                "required": ["path", "task"]
            ]
        )
    ] + MCPProviderTools.definitions

    static func call(name: String, arguments: [String: Any], context: MCPContext) async -> [String: Any] {
        do {
            switch name {
            case "list_secrets": return try await listSecrets(context: context)
            case "read_secret": return try await readSecret(args: arguments, context: context)
            case "set_mcp_allowed": return try await setMCPAllowed(args: arguments, context: context)
            case "scan_project": return try scanProject(args: arguments, context: context)
            case "get_audit_log": return try getAuditLog(args: arguments, context: context)
            case "suggest_secrets_for_task": return try suggestSecrets(args: arguments, context: context)
            case "reconcile_provider": return try await MCPProviderTools.reconcile(args: arguments, context: context)
            case "push_secrets": return try await MCPProviderTools.push(args: arguments, context: context)
            default: return errorResult("Unknown tool: \(name)")
            }
        } catch {
            return errorResult("\(error)")
        }
    }

    static func listSecrets(context: MCPContext) async throws -> [String: Any] {
        let allowed = try context.service.list()
            .filter(\.mcpAllowed)
            .sorted { $0.name < $1.name }
        if allowed.isEmpty {
            return textResult("(no MCP-allowed secrets — enable in Vibe Vault or use set_mcp_allowed)")
        }
        let lines = allowed.map { secret -> String in
            var bits = [secret.name]
            if secret.isExpired { bits.append("[expired]") }
            if secret.isRotationDue { bits.append("[rotate-due]") }
            return bits.joined(separator: " ")
        }
        return textResult(lines.joined(separator: "\n"))
    }

    static func readSecret(args: [String: Any], context: MCPContext) async throws -> [String: Any] {
        guard let name = args["name"] as? String else { return errorResult("missing 'name'") }
        guard let entry = try context.service.list().first(where: { $0.name == name }) else {
            return errorResult("secret '\(name)' not found")
        }
        if !entry.mcpAllowed {
            return errorResult(
                "secret '\(name)' is not MCP-accessible. Use set_mcp_allowed or toggle in Vibe Vault."
            )
        }
        let secret = try await context.service.read(
            name: name, reason: "MCP read via \(context.clientName)"
        )
        return textResult(secret.value)
    }

    static func setMCPAllowed(args: [String: Any], context: MCPContext) async throws -> [String: Any] {
        guard let name = args["name"] as? String else { return errorResult("missing 'name'") }
        guard let allowed = args["allowed"] as? Bool else { return errorResult("missing 'allowed'") }
        try await context.service.setMCPAllowed(name: name, allowed: allowed)
        return textResult(allowed ? "MCP access enabled for \(name)" : "MCP access revoked for \(name)")
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
        if !result.gitLeaks.isEmpty {
            lines.append("git-leaks: \(result.gitLeaks.joined(separator: ", "))")
            lines.append("hint: vibevault guard install — or git rm --cached <file>")
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

    static func suggestSecrets(args: [String: Any], context: MCPContext) throws -> [String: Any] {
        guard let path = args["path"] as? String else { return errorResult("missing 'path'") }
        guard let task = args["task"] as? String, !task.isEmpty else { return errorResult("missing 'task'") }
        let url = URL(fileURLWithPath: path)
        let known = Set(try context.service.list().map(\.name))
        let scan = try ProjectScanner().scan(projectURL: url, knownSecrets: known)
        let suggestion = SecretTaskSuggester.suggest(task: task, scan: scan, vaultNames: known)
        let lines = [
            "likely: \(suggestion.likely.joined(separator: ", "))",
            "in vault: \(suggestion.presentInVault.joined(separator: ", "))",
            "missing: \(suggestion.missingFromVault.joined(separator: ", "))",
            "(names only — never paste values into chat)"
        ]
        return textResult(lines.joined(separator: "\n"))
    }

    static func textResult(_ text: String) -> [String: Any] {
        ["content": [["type": "text", "text": text]]]
    }

    static func errorResult(_ message: String) -> [String: Any] {
        ["content": [["type": "text", "text": "Error: \(message)"]], "isError": true]
    }
}
