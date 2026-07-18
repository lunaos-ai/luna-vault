import Foundation

public struct ProviderPluginManifest: Codable, Equatable, Sendable {
    public let id: String
    public let displayName: String
    public let version: String
    public let requiredScopeKeys: [String]
    public let bundlePath: String?
    public let docsURL: String?

    public init(
        id: String,
        displayName: String,
        version: String,
        requiredScopeKeys: [String],
        bundlePath: String? = nil,
        docsURL: String? = nil
    ) {
        self.id = id
        self.displayName = displayName
        self.version = version
        self.requiredScopeKeys = requiredScopeKeys
        self.bundlePath = bundlePath
        self.docsURL = docsURL
    }
}

public enum PluginManifestLoader {
    public static var pluginsDirectory: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return base.appendingPathComponent("vibe-vault/plugins", isDirectory: true)
    }

    public static func loadAll() -> [ProviderPluginManifest] {
        let fm = FileManager.default
        let dir = pluginsDirectory
        guard let entries = try? fm.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil) else {
            return bundledExamples()
        }
        var manifests: [ProviderPluginManifest] = []
        for entry in entries where entry.pathExtension == "json" {
            if let m = load(url: entry) { manifests.append(m) }
        }
        return manifests.isEmpty ? bundledExamples() : manifests
    }

    public static func load(url: URL) -> ProviderPluginManifest? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(ProviderPluginManifest.self, from: data)
    }

    /// Shipped examples until SwiftPM plugin bundles land in v0.3.
    public static func bundledExamples() -> [ProviderPluginManifest] {
        [
            ProviderPluginManifest(
                id: "github-actions",
                displayName: "GitHub Actions",
                version: "0.0.0-stub",
                requiredScopeKeys: ["repository"],
                docsURL: "https://docs.github.com/en/actions/security-for-github-actions/security-guides/using-secrets-in-github-actions"
            ),
            ProviderPluginManifest(
                id: "aws-secrets-manager",
                displayName: "AWS Secrets Manager",
                version: "0.0.0-stub",
                requiredScopeKeys: ["region", "secret_arn"],
                docsURL: "https://docs.aws.amazon.com/secretsmanager/"
            )
        ]
    }
}
