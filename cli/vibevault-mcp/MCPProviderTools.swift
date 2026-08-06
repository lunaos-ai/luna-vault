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
                    "project_path": ["type": "string", "description": "Project root for Wrangler or local PushCI"],
                    "environment": ["type": "string", "description": "PushCI cloud secret environment (default *)"]
                ],
                "required": ["provider"]
            ]
        ),
        MCPToolDef(
            name: "push_secrets",
            description: "Push MCP-allowed vault secrets to Cloudflare, Vercel, or PushCI.",
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
                    "project_path": ["type": "string", "description": "Local PushCI project root or Wrangler project"],
                    "environment": ["type": "string", "description": "PushCI cloud secret environment (default *)"],
                    "allow_ci": ["type": "boolean", "description": "PushCI cloud: add names to ci_secret_names"],
                    "dry_run": ["type": "boolean", "description": "Print what would be pushed without sending."]
                ],
                "required": ["provider", "names"]
            ]
        ),
        MCPToolDef(
            name: "pull_secrets",
            description: "Pull secret names (and values where supported) from Cloudflare, Vercel, or PushCI.",
            inputSchema: [
                "type": "object",
                "properties": [
                    "provider": ["type": "string", "description": "cloudflare | vercel | pushci"],
                    "account_id": ["type": "string"],
                    "script_name": ["type": "string"],
                    "project_id": ["type": "string", "description": "Vercel project id, or PushCI cloud project UUID"],
                    "team_id": ["type": "string"],
                    "project_path": ["type": "string", "description": "Local PushCI project root or Wrangler project"],
                    "environment": ["type": "string", "description": "PushCI cloud secret environment (default *)"],
                    "import_secrets": ["type": "boolean", "description": "Import pulled secrets with non-empty values into the local vault."]
                ],
                "required": ["provider"]
            ]
        )
    ]

    static func reconcile(args: [String: Any], context: MCPContext) async throws -> [String: Any] {
        guard let providerId = args["provider"] as? String else {
            return MCPTools.errorResult("missing 'provider'")
        }
        let provider = try resolveProvider(id: providerId, context: context)
        let target = try MCPProviderTarget.resolve(id: providerId, args: args)
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
        let target = try MCPProviderTarget.resolve(id: providerId, args: args)
        if (args["dry_run"] as? Bool) == true {
            let dest = target.scope["project_id"].map { "cloud project \($0)" }
                ?? target.scope["project_path"].map { "local \($0)" }
                ?? provider.displayName
            return MCPTools.textResult("[dry-run] would push \(names.count) secrets to \(dest):\n" +
                names.map { "  - \($0)" }.joined(separator: "\n"))
        }
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

    static func pull(args: [String: Any], context: MCPContext) async throws -> [String: Any] {
        guard let providerId = args["provider"] as? String else {
            return MCPTools.errorResult("missing 'provider'")
        }
        let provider = try resolveProvider(id: providerId, context: context)
        let target = try MCPProviderTarget.resolve(id: providerId, args: args)
        let secrets = try await provider.pull(target: target)
        let shouldImport = (args["import_secrets"] as? Bool) == true
        if shouldImport {
            let items = secrets
                .filter { !$0.value.isEmpty }
                .map { VaultService.ImportItem(name: $0.name, value: $0.value, notes: "imported from \(provider.displayName)") }
            let result = try context.service.importSecrets(items, overwrite: true)
            let lines = [
                "pulled: \(secrets.count)",
                "imported: \(result.imported.count)",
                "updated: \(result.updated.count)",
                "skipped: \(result.skipped.count)",
                "failed: \(result.failed.count)"
            ]
            if !result.failed.isEmpty {
                let failures = result.failed.map { "\($0.0): \($0.1)" }.joined(separator: "; ")
                return MCPTools.textResult(lines.joined(separator: "\n") + "\n" + failures)
            }
            return MCPTools.textResult(lines.joined(separator: "\n"))
        }
        let lines = secrets.map { secret in
            secret.value.isEmpty
                ? "\(secret.name)  (value not retrievable from \(provider.displayName))"
                : "\(secret.name)=\(secret.maskedValue)"
        }
        return MCPTools.textResult(lines.joined(separator: "\n"))
    }

    private static func resolveProvider(id: String, context: MCPContext) throws -> SecretProvider {
        guard let p = context.registry.provider(id: id) else {
            throw ProviderError.unsupported(id)
        }
        return p
    }
}
