import Foundation
import VaultCore

enum MCPProviderTarget {
    static func resolve(id providerId: String, args: [String: Any]) throws -> ProviderTarget {
        var scope = try scopePairs(from: args)
        switch providerId {
        case "cloudflare":
            let projectURL = URL(fileURLWithPath: projectPath(from: args)).standardizedFileURL
            let wrangler = WranglerConfig.load(from: projectURL)
            if scope["account_id"] == nil, let accountId = wrangler.accountId {
                scope["account_id"] = accountId
            }
            if scope["script_name"] == nil, let scriptName = wrangler.scriptName {
                scope["script_name"] = scriptName
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
            guard scope["project_id"] != nil else {
                throw ProviderError.missingScope("project_id")
            }
        case "pushci":
            let env = ProcessInfo.processInfo.environment
            if scope["project_id"] == nil {
                scope["project_id"] = firstEnv(env, ["PUSHCI_PROJECT_ID"])
            }
            if scope["environment"] == nil {
                scope["environment"] = firstEnv(env, ["PUSHCI_SECRET_ENVIRONMENT"]) ?? "*"
            }
            if let allow = args["allow_ci"] as? Bool, allow {
                scope["allow_ci"] = "true"
            }
            if let allow = args["allow_ci"] as? String, ["1", "true", "yes"].contains(allow.lowercased()) {
                scope["allow_ci"] = "true"
            }
            guard scope["project_id"] != nil || scope["project_path"] != nil else {
                throw ProviderError.missingScope("project_id (cloud) or project_path (local CLI)")
            }
        default:
            throw ProviderError.unsupported(providerId)
        }
        return ProviderTarget(provider: providerId, scope: scope)
    }

    private static func scopePairs(from args: [String: Any]) throws -> [String: String] {
        var scope: [String: String] = [:]
        for key in ["account_id", "script_name", "project_id", "team_id", "project_path", "environment"] {
            if let value = args[key] as? String, !value.isEmpty {
                scope[key] = value
            }
        }
        if let project = args["project"] as? String, !project.isEmpty, scope["project_path"] == nil {
            scope["project_path"] = project
        }
        if let raw = args["scope"] as? [String] {
            for pair in raw {
                let parts = pair.split(separator: "=", maxSplits: 1).map(String.init)
                guard parts.count == 2 else {
                    throw ProviderError.missingScope("invalid scope pair: \(pair) (use key=value)")
                }
                let key = parts[0].trimmingCharacters(in: .whitespaces)
                let value = parts[1].trimmingCharacters(in: .whitespaces)
                guard !key.isEmpty, !value.isEmpty else {
                    throw ProviderError.missingScope("invalid scope pair: \(pair)")
                }
                scope[key] = value
            }
        }
        return scope
    }

    private static func projectPath(from args: [String: Any]) -> String {
        if let path = args["project_path"] as? String, !path.isEmpty { return path }
        if let project = args["project"] as? String, !project.isEmpty { return project }
        return FileManager.default.currentDirectoryPath
    }

    private static func firstEnv(_ env: [String: String], _ names: [String]) -> String? {
        for name in names {
            let value = env[name]?.trimmingCharacters(in: .whitespaces)
            if value?.isEmpty == false { return value }
        }
        return nil
    }
}
