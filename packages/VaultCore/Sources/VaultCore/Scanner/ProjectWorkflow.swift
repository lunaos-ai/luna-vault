import Foundation

public enum ProjectWorkflow {
    @discardableResult
    public static func scanAndRemember(
        projectURL: URL,
        vaultNames: [String],
        prefix: String? = nil,
        registry: ProjectRegistry = ProjectRegistry()
    ) throws -> ScanResult {
        let root = projectURL.standardizedFileURL
        try ProjectScanner.validateRoot(root)
        let record = try registry.upsert(url: root, prefix: prefix)
        let known = SecretNaming.knownNames(vaultNames: vaultNames, prefix: record.prefix)
        let result = try ProjectScanner().scan(projectURL: root, knownSecrets: known)
        try registry.recordScan(id: record.id, result: result, url: root)
        return result
    }
}
