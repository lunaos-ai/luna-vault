import Foundation

/// Import a JSON file as either a map of string secrets or one JSON document.
public enum JSONSecretsImporter {
    public static func parseFile(at url: URL, defaultName: String? = nil) throws -> [VaultService.ImportItem] {
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw ImporterError.fileNotFound(url.path)
        }
        let content = try String(contentsOf: url, encoding: .utf8)
        let stem = url.deletingPathExtension().lastPathComponent
        let fallback = defaultName ?? SecretNaming.sanitizePrefix(stem)
        return try parse(content, defaultName: fallback.isEmpty ? "JSON_SECRET" : fallback)
    }

    public static func parse(_ content: String, defaultName: String) throws -> [VaultService.ImportItem] {
        let object = try SecretJSON.parse(content)
        if let dict = object as? [String: Any], let flat = flattenStringMap(dict) {
            return flat
        }
        let pretty = try SecretJSON.prettyPrinted(content)
        return [
            VaultService.ImportItem(
                name: defaultName,
                value: pretty,
                notes: "imported as JSON",
                valueKind: .json
            )
        ]
    }

    private static func flattenStringMap(_ dict: [String: Any]) -> [VaultService.ImportItem]? {
        guard !dict.isEmpty, dict.keys.allSatisfy(looksLikeEnvKey) else { return nil }
        var items: [VaultService.ImportItem] = []
        for (key, value) in dict {
            guard let string = value as? String, !string.isEmpty else { return nil }
            let name = SecretNaming.sanitizePrefix(key)
            guard !name.isEmpty else { return nil }
            items.append(VaultService.ImportItem(name: name, value: string))
        }
        return items.sorted { $0.name < $1.name }
    }

    private static func looksLikeEnvKey(_ key: String) -> Bool {
        if key.contains("_") { return true }
        let letters = key.filter(\.isLetter)
        return key.count >= 3 && letters.count == key.count && key == key.uppercased()
    }
}
