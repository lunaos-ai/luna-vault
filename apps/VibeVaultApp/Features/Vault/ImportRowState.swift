import Foundation
import VaultCore

struct ImportRowState: Identifiable {
    let sourceName: String
    let value: String
    let sourceFile: String?
    var enabled = true
    var id: String { sourceName }

    func vaultName(prefix: String) -> String {
        guard !prefix.isEmpty else { return sourceName }
        return SecretNaming.applyPrefix(prefix, to: sourceName)
    }

    static func from(_ items: [VaultService.ImportItem], sourceFile: String? = nil) -> [ImportRowState] {
        items.map { ImportRowState(sourceName: $0.name, value: $0.value, sourceFile: sourceFile) }
    }
}
