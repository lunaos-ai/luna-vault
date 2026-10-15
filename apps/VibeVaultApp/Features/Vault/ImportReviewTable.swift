import SwiftUI
import VaultCore

struct ImportReviewTable: View {
    @Binding var rows: [ImportRowState]
    let prefix: String
    let sourceColumnTitle: String
    @Binding var showValues: Bool

    var body: some View {
        Table(rows) {
            TableColumn("") { row in
                Toggle("", isOn: enabledBinding(for: row)).labelsHidden()
            }
            .width(28)
            TableColumn(sourceColumnTitle) { row in
                TextField("NAME", text: nameBinding(for: row))
                    .font(.system(.body, design: .monospaced))
                    .textFieldStyle(.plain)
                    .help("Rename before import")
            }
            TableColumn("Vault name") { row in
                Text(row.vaultName(prefix: prefix))
                    .font(.system(.body, design: .monospaced))
                    .foregroundStyle(prefix.isEmpty ? Tokens.Text.secondary : Tokens.Palette.accent)
                    .lineLimit(1)
                    .help("Final name written to the vault")
            }
            TableColumn("Source") { row in
                Text(row.sourceFile ?? "—")
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(Tokens.Text.tertiary)
                    .lineLimit(1)
            }
            TableColumn("MFA") { row in
                if row.totpAuthURL != nil {
                    Label("Code", systemImage: "number.square")
                        .font(.caption)
                        .foregroundStyle(Tokens.Status.info)
                } else {
                    Text("—")
                        .foregroundStyle(Tokens.Text.tertiary)
                }
            }
            .width(64)
            TableColumn("Format") { row in
                Text(row.valueKind.label)
                    .foregroundStyle(Tokens.Text.secondary)
            }
            .width(56)
            TableColumn("Value") { row in
                Text(valuePreview(row))
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(Tokens.Text.secondary)
                    .lineLimit(1)
                    .help(row.valueKind == .json ? SecretJSON.maskedSummary(row.value) : row.name)
            }
        }
        .frame(maxHeight: 280)
    }

    private func valuePreview(_ row: ImportRowState) -> String {
        if row.valueKind == .json {
            return showValues
                ? ((try? SecretJSON.compactPrinted(row.value)) ?? row.value)
                : SecretJSON.maskedSummary(row.value)
        }
        return showValues ? row.value : SecretNaming.maskedValue(row.value)
    }

    private func enabledBinding(for row: ImportRowState) -> Binding<Bool> {
        binding(for: row, keyPath: \.enabled, fallback: row.enabled)
    }

    private func nameBinding(for row: ImportRowState) -> Binding<String> {
        binding(for: row, keyPath: \.name, fallback: row.name)
    }

    private func binding<T>(
        for row: ImportRowState,
        keyPath: WritableKeyPath<ImportRowState, T>,
        fallback: T
    ) -> Binding<T> {
        guard let idx = rows.firstIndex(where: { $0.id == row.id }) else {
            return .constant(fallback)
        }
        return Binding(
            get: { rows[idx][keyPath: keyPath] },
            set: { rows[idx][keyPath: keyPath] = $0 }
        )
    }
}
