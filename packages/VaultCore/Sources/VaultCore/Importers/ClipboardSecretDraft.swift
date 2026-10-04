import Foundation

/// A single secret draft parsed from clipboard text for New Secret.
public struct ClipboardSecretDraft: Equatable, Sendable {
    public let name: String
    public let value: String
    public let valueKind: SecretValueKind

    public static func parse(_ content: String) -> ClipboardSecretDraft? {
        let dotenv = DotenvImporter.parse(content)
        if dotenv.count == 1, let item = dotenv.first {
            return from(item)
        }
        guard dotenv.isEmpty,
              let json = try? JSONSecretsImporter.parse(content, defaultName: ""),
              json.count == 1,
              let item = json.first else { return nil }
        return from(item)
    }

    public static func fromPastedName(_ pasted: String, valueIsEmpty: Bool) -> ClipboardSecretDraft? {
        guard valueIsEmpty, pasted.contains("=") else { return nil }
        guard let draft = parse(pasted), !draft.name.isEmpty else { return nil }
        return draft
    }

    public static func fromPasteboard() -> ClipboardSecretDraft? {
        guard let content = PlatformClipboard.readString() else { return nil }
        return parse(content)
    }

    private static func from(_ item: VaultService.ImportItem) -> ClipboardSecretDraft {
        if item.valueKind == .json {
            return ClipboardSecretDraft(name: item.name, value: item.value, valueKind: .json)
        }
        if let pretty = try? SecretJSON.prettyPrinted(item.value) {
            return ClipboardSecretDraft(name: item.name, value: pretty, valueKind: .json)
        }
        return ClipboardSecretDraft(name: item.name, value: item.value, valueKind: .text)
    }
}
