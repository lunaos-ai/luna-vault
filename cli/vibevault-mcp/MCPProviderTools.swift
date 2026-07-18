import Foundation
import VaultCore

enum MCPProviderTools {
    static let definitions: [MCPToolDef] = [
        MCPToolDef(
            name: "reconcile_provider",
            description: "Compare vault secret names with Cloudflare, Vercel, or PushCI (names only).",
            inputSchema: [
                "type": "object",
                "properties": [
                    "provider": ["type": "string", "description": "cloudflare | vercel | pushci"],
                    "account_id": ["type": "string"],
                    "script_name": ["type": "string"],
                    "project_id": ["type": "string"],
                    "team_id": ["type": "string"],
                    "project_path": ["type": "string", "description": "PushCI project root (absolute path)"]
                ],
                "required": ["provider"]
            ]
        ),
        MCPToolDef(
            name: "push_secrets",
            description: "Push MCP-allowed vault secrets to Cloudflare, Vercel, or PushCI local store.",
            inputSchema: [
                "type": "object",
                "properties": [
                    "provider": ["type": "string", "description": "cloudflare | vercel | pushci"],
                    "names": [
                        "type": "array",
                        "items": ["type": "string"],
                        "description": "Vault secret names (must be MCP-allowed)."
                    ],
                    "account_id": ["type": "string"],
                    "script_name": ["type": "string"],
                    "project_id": ["type": "string"],
                    "team_id": ["type": "string"],
                    "project_path": ["type": "string"]
                ],
                "required": ["provider", "names"]
            ]
        )
    ]

    static func reconcile(args: [String: Any], context: MCPContext) async throws -> [String: Any] {
        guard let providerId = args["provider"] as? String else {
            return MCPTools.errorResult("missing 'provider'")
        }
        let provider = try resolveProvider(id: providerId, context: context)
        let target = try target(for: providerId, args: args)
        let local = Set(try context.service.list().map(\.name))
        let r = try await ProviderNameSync.reconcile(
            provider: provider, target: target, localNames: local
        )
        let lines = [
            "remote: \(r.remoteNames.count)",
            "local: \(r.localNames.count)",
            "missing locally: \(Array(r.missingLocally).sorted().joined(separator: ", "))",
            "extra locally: \(Array(r.extraLocally).sorted().joined(separator: ", "))",
            "in sync: \(Array(r.inSync).sorted().joined(separator: ", "))"
        ]
        return MCPTools.textResult(lines.joined(separator: "\n"))
    }

    static func push(args: [String: Any], context: MCPContext) async throws -> [String: Any] {
        guard let providerId = args["provider"] as? String else {
            return MCPTools.errorResult("missing 'provider'")
        }
        guard let names = args["names"] as? [String], !names.isEmpty else {
            return MCPTools.errorResult("missing 'names'")
        }
        let allowed = Set(try context.service.list().filter(\.mcpAllowed).map(\.name))
        let blocked = names.filter { !allowed.contains($0) }
        if !blocked.isEmpty {
            return MCPTools.errorResult(
                "not MCP-allowed: \(blocked.sorted().joined(separator: ", ")). Enable AI access in the Vibe Vault app."
            )
        }
        let provider = try resolveProvider(id: providerId, context: context)
        let target = try target(for: providerId, args: args)
        var items: [Secret] = []
        for name in names {
            let secret = try await context.service.read(
                name: name, reason: "MCP push to \(providerId) via \(context.clientName)"
            )
            items.append(Secret(name: name, value: secret.value))
        }
        let result = try await provider.push(secrets: items, target: target)
        for name in result.pushed {
            try context.service.recordEvent(name: name, action: .push, projectPath: nil)
        }
        let failed = result.failed.map { "\($0.name): \($0.reason)" }.joined(separator: "; ")
        return MCPTools.textResult(
            "pushed: \(result.pushed.joined(separator: ", "))"
                + (failed.isEmpty ? "" : "\nfailed: \(failed)")
        )
    }

    private static func resolveProvider(id: String, context: MCPContext) throws -> SecretProvider {
        guard let p = context.registry.provider(id: id) else {
            throw ProviderError.unsupported(id)
        }
        return p
    }

    private static func target(for providerId: String, args: [String: Any]) throws -> ProviderTarget {
        var scope: [String: String] = [:]
        switch providerId {
        case "cloudflare":
            if let a = args["account_id"] as? String, !a.isEmpty { scope["account_id"] = a }
            if let s = args["script_name"] as? String, !s.isEmpty { scope["script_name"] = s }
            guard scope["account_id"] != nil, scope["script_name"] != nil else {
                throw ProviderError.missingScope("account_id + script_name")
            }
        case "vercel":
            if let p = args["project_id"] as? String, !p.isEmpty { scope["project_id"] = p }
            if let t = args["team_id"] as? String, !t.isEmpty { scope["team_id"] = t }
            guard scope["project_id"] != nil else {
                throw ProviderError.missingScope("project_id")
            }
        case "pushci":
            if let p = args["project_path"] as? String, !p.isEmpty { scope["project_path"] = p }
            guard scope["project_path"] != nil else {
                throw ProviderError.missingScope("project_path")
            }
        default:
            throw ProviderError.unsupported(providerId)
        }
        return ProviderTarget(provider: providerId, scope: scope)
    }
}
