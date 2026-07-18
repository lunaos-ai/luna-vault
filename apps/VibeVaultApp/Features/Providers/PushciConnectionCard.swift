import SwiftUI

struct PushciConnectionCard: View {
    @Binding var projectPath: String
    let cliReady: Bool
    let lastScannedPath: String?

    var body: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.md) {
            HStack(spacing: Tokens.Space.md) {
                ZStack {
                    RoundedRectangle(cornerRadius: Tokens.Radius.sm, style: .continuous)
                        .fill(Tokens.Palette.accent.opacity(0.12))
                        .frame(width: 40, height: 40)
                    Image(systemName: "terminal.fill")
                        .foregroundStyle(Tokens.Palette.accent)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("pushci.dev").font(.headline)
                    Text(statusLine)
                        .font(.caption)
                        .foregroundStyle(Tokens.Text.secondary)
                }
                Spacer()
                Text(ready ? "Ready" : "Setup")
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, Tokens.Space.sm)
                    .padding(.vertical, Tokens.Space.xs)
                    .background(
                        (ready ? Tokens.Status.success : Tokens.Status.warning).opacity(0.12),
                        in: Capsule()
                    )
                    .foregroundStyle(ready ? Tokens.Status.success : Tokens.Status.warning)
            }
            VStack(alignment: .leading, spacing: Tokens.Space.xs) {
                Text("Project path").font(.caption.weight(.semibold)).foregroundStyle(Tokens.Text.secondary)
                TextField("Path to PushCI project root", text: $projectPath)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(.caption, design: .monospaced))
            }
            if let last = lastScannedPath, !last.isEmpty, last != projectPath {
                Button("Use last scanned project") { projectPath = last }
                    .font(.caption)
                    .buttonStyle(.borderless)
            }
            Text("Writes to `.pushci/secrets.enc` via `pushci secret`. Requires PushCI CLI on PATH.")
                .font(.caption2)
                .foregroundStyle(Tokens.Text.tertiary)
        }
        .padding(Tokens.Space.lg)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: Tokens.Radius.lg, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Tokens.Radius.lg, style: .continuous)
                .strokeBorder(Tokens.Surface.separator.opacity(0.6), lineWidth: Tokens.Stroke.hairline)
        )
    }

    private var ready: Bool { cliReady && !projectPath.isEmpty }

    private var statusLine: String {
        if ready { return "Sync local PushCI secrets for this machine" }
        if projectPath.isEmpty { return "Choose a project with `pushci init`" }
        return "Install PushCI CLI: brew install pushci"
    }
}
