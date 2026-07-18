import SwiftUI
import VaultCore

struct VercelConnectionCard: View {
    @Binding var projectId: String
    @Binding var teamId: String
    let tokenReady: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.md) {
            HStack(spacing: Tokens.Space.md) {
                ZStack {
                    RoundedRectangle(cornerRadius: Tokens.Radius.sm, style: .continuous)
                        .fill(Tokens.Palette.accent.opacity(0.12))
                        .frame(width: 40, height: 40)
                    Image(systemName: "triangle.fill")
                        .foregroundStyle(Tokens.Palette.accent)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("Vercel").font(.headline)
                    Text(statusLine)
                        .font(.caption)
                        .foregroundStyle(Tokens.Text.secondary)
                }
                Spacer()
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
            HStack(spacing: Tokens.Space.md) {
                field("Project ID", text: $projectId)
                field("Team ID (optional)", text: $teamId)
            }
        }
        .padding(Tokens.Space.lg)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: Tokens.Radius.lg, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Tokens.Radius.lg, style: .continuous)
                .strokeBorder(Tokens.Surface.separator.opacity(0.6), lineWidth: Tokens.Stroke.hairline)
        )
    }

    private var ready: Bool { tokenReady && !projectId.isEmpty }

    private var statusLine: String {
        if ready { return "Ready to sync env to project \(projectId)" }
        if !tokenReady { return "Add API token in Settings" }
        return "Enter Vercel project ID"
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
