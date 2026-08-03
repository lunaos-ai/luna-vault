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
                    "project_id": ["type": "string", "description": "Vercel project id, or PushCI cloud project UUID"],
                    "team_id": ["type": "string"],
                    "project_path": ["type": "string", "description": "Project root for Wrangler or local PushCI"]
                ],
                "required": ["provider"]
            ]
        ),
        MCPToolDef(
            name: "push_secrets",
            description: "Push MCP-allowed vault secrets to Cloudflare, Vercel, or PushCI (local CLI or cloud project secrets).",
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
                    "project_id": ["type": "string", "description": "Vercel project id, or PushCI cloud project UUID"],
                    "team_id": ["type": "string"],
                    "project_path": ["type": "string", "description": "Local PushCI project root (CLI secret store)"],
                    "environment": ["type": "string", "description": "PushCI cloud secret environment (default *)"],
                    "allow_ci": ["type": "boolean", "description": "PushCI cloud: add names to ci_secret_names"]
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
            if let path = args["project_path"] as? String, !path.isEmpty {
                let cfg = WranglerConfig.load(from: URL(fileURLWithPath: path).standardizedFileURL)
                if scope["account_id"] == nil, let accountId = cfg.accountId { scope["account_id"] = accountId }
                if scope["script_name"] == nil, let scriptName = cfg.scriptName { scope["script_name"] = scriptName }
            }
            let env = ProcessInfo.processInfo.environment
            if scope["account_id"] == nil {
                scope["account_id"] = firstEnv(env, ["CLOUDFLARE_ACCOUNT_ID", "CF_ACCOUNT_ID"])
            }
            if scope["script_name"] == nil {
                scope["script_name"] = firstEnv(env, ["CLOUDFLARE_SCRIPT_NAME", "CF_SCRIPT_NAME", "WRANGLER_SCRIPT_NAME"])
            }
            guard scope["account_id"] != nil, scope["script_name"] != nil else {
                throw ProviderError.missingScope(
                    "account_id + script_name, project_path with Wrangler config, or Cloudflare env vars"
                )
            }
        case "vercel":
            if let p = args["project_id"] as? String, !p.isEmpty { scope["project_id"] = p }
            if let t = args["team_id"] as? String, !t.isEmpty { scope["team_id"] = t }
            guard scope["project_id"] != nil else {
                throw ProviderError.missingScope("project_id")
            }
        case "pushci":
            if let p = args["project_id"] as? String, !p.isEmpty { scope["project_id"] = p }
            if let p = args["project_path"] as? String, !p.isEmpty { scope["project_path"] = p }
            if let e = args["environment"] as? String, !e.isEmpty { scope["environment"] = e }
            if let allow = args["allow_ci"] as? Bool, allow { scope["allow_ci"] = "true" }
            if let allow = args["allow_ci"] as? String, ["1", "true", "yes"].contains(allow.lowercased()) {
                scope["allow_ci"] = "true"
            }
            let env = ProcessInfo.processInfo.environment
            if scope["project_id"] == nil {
                scope["project_id"] = firstEnv(env, ["PUSHCI_PROJECT_ID"])
            }
            guard scope["project_id"] != nil || scope["project_path"] != nil else {
                throw ProviderError.missingScope("project_id (cloud) or project_path (local CLI)")
            }
        default:
            throw ProviderError.unsupported(providerId)
        }
        return ProviderTarget(provider: providerId, scope: scope)
    }

    private static func firstEnv(_ env: [String: String], _ names: [String]) -> String? {
        for name in names {
            let value = env[name]?.trimmingCharacters(in: .whitespacesAndNewlines)
            if value?.isEmpty == false { return value }
        }
        return nil
    }
}
