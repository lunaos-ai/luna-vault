import ArgumentParser
import Foundation
import VaultCore

enum ProviderScopeResolver {
    static func target(provider: String, pairs: [String], projectPath: String?) throws -> ProviderTarget {
        var scopeMap = try scopePairs(pairs)
        if provider == "cloudflare" {
            let projectURL = URL(fileURLWithPath: projectPath ?? FileManager.default.currentDirectoryPath)
                .standardizedFileURL
            let wrangler = WranglerConfig.load(from: projectURL)
            if scopeMap["account_id"] == nil, let accountId = wrangler.accountId {
                scopeMap["account_id"] = accountId
            }
            if scopeMap["script_name"] == nil, let scriptName = wrangler.scriptName {
                scopeMap["script_name"] = scriptName
            }
            let env = ProcessInfo.processInfo.environment
            if scopeMap["account_id"] == nil {
                scopeMap["account_id"] = firstEnv(env, ["CLOUDFLARE_ACCOUNT_ID", "CF_ACCOUNT_ID"])
            }
            if scopeMap["script_name"] == nil {
                scopeMap["script_name"] = firstEnv(env, ["CLOUDFLARE_SCRIPT_NAME", "CF_SCRIPT_NAME", "WRANGLER_SCRIPT_NAME"])
            }
        }
        return ProviderTarget(provider: provider, scope: scopeMap)
    }

    private static func scopePairs(_ pairs: [String]) throws -> [String: String] {
        var scopeMap: [String: String] = [:]
        for pair in pairs {
            let parts = pair.split(separator: "=", maxSplits: 1).map(String.init)
            guard parts.count == 2 else {
                throw ValidationError("invalid scope pair: \(pair) (use key=value)")
            }
            let key = parts[0].trimmingCharacters(in: .whitespacesAndNewlines)
            let value = parts[1].trimmingCharacters(in: .whitespacesAndNewlines)
            guard !key.isEmpty, !value.isEmpty else {
                throw ValidationError("invalid scope pair: \(pair) (key and value must be non-empty)")
            }
            scopeMap[key] = value
        }
        return scopeMap
    }

    private static func firstEnv(_ env: [String: String], _ names: [String]) -> String? {
        for name in names {
            let value = env[name]?.trimmingCharacters(in: .whitespacesAndNewlines)
            if value?.isEmpty == false { return value }
        }
        return nil
    }
}
