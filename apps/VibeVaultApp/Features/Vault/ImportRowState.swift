import Foundation
import VaultCore

struct ImportRowState: Identifiable {
    let sourceName: String
    /// Editable vault base name (prefix applied on import).
    var name: String
    let value: String
    let sourceFile: String?
    var enabled = true

    var id: String { sourceName }

    init(sourceName: String, value: String, sourceFile: String? = nil, enabled: Bool = true) {
        self.sourceName = sourceName
        self.name = sourceName
        self.value = value
        self.sourceFile = sourceFile
        self.enabled = enabled
    }

    func vaultName(prefix: String) -> String {
        let base = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let resolved = base.isEmpty ? sourceName : base
        guard !prefix.isEmpty else { return resolved }
        return SecretNaming.applyPrefix(prefix, to: resolved)
    }

    static func from(_ items: [VaultService.ImportItem], sourceFile: String? = nil) -> [ImportRowState] {
        items.map { ImportRowState(sourceName: $0.name, value: $0.value, sourceFile: sourceFile) }
    }
}
