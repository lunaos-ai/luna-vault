import SwiftUI
import VaultCore

struct ImportReviewTable: View {
    @Binding var rows: [ImportRowState]
    let prefix: String
    let showPrefixColumn: Bool
    let sourceColumnTitle: String
    @Binding var showValues: Bool

    var body: some View {
        if showPrefixColumn {
            prefixedTable
        } else {
            plainTable
        }
    }

    private var prefixedTable: some View {
        Table(rows) {
            TableColumn("") { row in
                Toggle("", isOn: binding(for: row)).labelsHidden()
            }
            .width(28)
            TableColumn(sourceColumnTitle) { row in
                Text(row.sourceName).font(.system(.body, design: .monospaced))
            }
            TableColumn("Vault name") { row in
                Text(row.vaultName(prefix: prefix))
                    .font(.system(.body, design: .monospaced))
                    .foregroundStyle(Tokens.Palette.accent)
            }
            TableColumn("Source") { row in
                Text(row.sourceFile ?? "—")
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(Tokens.Text.tertiary)
                    .lineLimit(1)
            }
            TableColumn("Value") { row in
                valueCell(row)
            }
        }
        .frame(maxHeight: 280)
    }

    private var plainTable: some View {
        Table(rows) {
            TableColumn("") { row in
                Toggle("", isOn: binding(for: row)).labelsHidden()
            }
            .width(28)
            TableColumn(sourceColumnTitle) { row in
                Text(row.sourceName).font(.system(.body, design: .monospaced))
            }
            TableColumn("Source") { row in
                Text(row.sourceFile ?? "—")
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(Tokens.Text.tertiary)
                    .lineLimit(1)
            }
            TableColumn("Value") { row in
                valueCell(row)
            }
        }
        .frame(maxHeight: 280)
    }

    private func valueCell(_ row: ImportRowState) -> some View {
        Text(showValues ? row.value : SecretNaming.maskedValue(row.value))
            .font(.system(.caption, design: .monospaced))
            .foregroundStyle(Tokens.Text.secondary)
            .lineLimit(1)
    }

    private func binding(for row: ImportRowState) -> Binding<Bool> {
        guard let idx = rows.firstIndex(where: { $0.id == row.id }) else {
            return .constant(row.enabled)
        }
        return $rows[idx].enabled
    }
}
