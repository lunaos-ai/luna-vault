import SwiftUI

/// Paste-and-save API token sheet used from Providers "Setup".
struct ProviderTokenSetupSheet: View {
    let title: String
    let prompt: String
    let dashboardURL: URL
    let dashboardLabel: String
    let footer: String
    let onSave: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var token = ""

    var body: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.lg) {
            Text(title)
                .font(.system(size: 18, weight: .semibold))
            SecureField(prompt, text: $token, prompt: Text(prompt))
                .textFieldStyle(.roundedBorder)
                .font(.system(.body, design: .monospaced))
            Text(footer)
                .font(.caption)
                .foregroundStyle(Tokens.Text.secondary)
            Link(destination: dashboardURL) {
                Label(dashboardLabel, systemImage: "arrow.up.right.square")
            }
            .font(.caption)
            HStack {
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Spacer()
                Button("Save token") {
                    let trimmed = token.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !trimmed.isEmpty else { return }
                    onSave(trimmed)
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .tint(Tokens.Palette.accent)
                .disabled(token.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(Tokens.Space.xl)
        .frame(width: 440)
    }
}
