import SwiftUI
import VaultCore

struct CloudflareConnectionCard: View {
    @Binding var accountId: String
    @Binding var scriptName: String
    let tokenReady: Bool
    let wranglerDetected: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.md) {
            HStack(spacing: Tokens.Space.md) {
                ZStack {
                    RoundedRectangle(cornerRadius: Tokens.Radius.sm, style: .continuous)
                        .fill(Tokens.Palette.accent.opacity(0.12))
                        .frame(width: 40, height: 40)
                    Image(systemName: "cloud.fill")
                        .foregroundStyle(Tokens.Palette.accent)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("Cloudflare Workers")
                        .font(.headline)
                    Text(statusLine)
                        .font(.caption)
                        .foregroundStyle(Tokens.Text.secondary)
                }
                Spacer()
                statusChip
            }
            HStack(spacing: Tokens.Space.md) {
                field("Account ID", text: $accountId)
                field("Script name", text: $scriptName)
            }
            if wranglerDetected {
                Label("Filled from wrangler.toml", systemImage: "doc.text")
                    .font(.caption)
                    .foregroundStyle(Tokens.Text.tertiary)
            }
        }
        .padding(Tokens.Space.lg)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: Tokens.Radius.lg, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Tokens.Radius.lg, style: .continuous)
                .strokeBorder(Tokens.Surface.separator.opacity(0.6), lineWidth: Tokens.Stroke.hairline)
        )
    }

    private var statusLine: String {
        if tokenReady && !accountId.isEmpty && !scriptName.isEmpty {
            return "Ready to sync secrets to \(scriptName)"
        }
        if !tokenReady { return "Add API token in Settings" }
        return "Enter account ID and script name"
    }

    @ViewBuilder
    private var statusChip: some View {
        let ready = tokenReady && !accountId.isEmpty && !scriptName.isEmpty
        Text(ready ? "Connected" : "Setup")
            .font(.caption.weight(.semibold))
            .padding(.horizontal, Tokens.Space.sm)
            .padding(.vertical, Tokens.Space.xs)
            .background(
                (ready ? Tokens.Status.success : Tokens.Status.warning).opacity(0.12),
                in: Capsule()
            )
            .foregroundStyle(ready ? Tokens.Status.success : Tokens.Status.warning)
    }

    private func field(_ label: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: Tokens.Space.xs) {
            Text(label).font(.caption.weight(.semibold)).foregroundStyle(Tokens.Text.secondary)
            TextField(label, text: text)
                .textFieldStyle(.roundedBorder)
                .font(.system(.caption, design: .monospaced))
        }
    }
}
