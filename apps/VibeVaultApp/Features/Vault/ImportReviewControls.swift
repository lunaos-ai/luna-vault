import SwiftUI

struct ImportReviewControls: View {
    @Binding var prefix: String
    @Binding var showValues: Bool
    @Binding var overwrite: Bool
    @Binding var allowForAI: Bool
    let showPrefix: Bool
    let selectedCount: Int
    let exampleVaultName: String?
    let onPrefixChange: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.sm) {
            if showPrefix {
                HStack(spacing: Tokens.Space.md) {
                    Text("Project prefix")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Tokens.Text.secondary)
                    TextField("MYAPP_", text: $prefix)
                        .font(.system(.body, design: .monospaced))
                        .textFieldStyle(.roundedBorder)
                        .frame(maxWidth: 220)
                        .help("Prepended to each name on import, e.g. MYAPP_CLERK_SECRET_KEY")
                        .onChange(of: prefix) { _, v in onPrefixChange(v) }
                    if !prefix.isEmpty, let example = exampleVaultName {
                        Text("e.g. \(example)")
                            .font(.system(.caption, design: .monospaced))
                            .foregroundStyle(Tokens.Text.tertiary)
                            .lineLimit(1)
                    }
                    Spacer()
                }
            }
            HStack(spacing: Tokens.Space.lg) {
                Toggle("Show values", isOn: $showValues)
                Toggle("Overwrite existing", isOn: $overwrite)
                Toggle("Allow AI agents", isOn: $allowForAI)
                    .help("Expose imported secrets to Cursor, VS Code, and Devin via MCP.")
                Spacer()
                Text("\(selectedCount) selected")
                    .font(.caption)
                    .foregroundStyle(Tokens.Text.secondary)
            }
        }
    }
}
