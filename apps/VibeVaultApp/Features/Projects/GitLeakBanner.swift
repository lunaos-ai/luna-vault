import SwiftUI
import VaultCore

struct GitLeakBanner: View {
    let leaks: [String]
    let projectURL: URL?
    var onInstallHook: (() -> Void)?
    var onFixIgnores: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.sm) {
            HStack(spacing: Tokens.Space.sm) {
                Image(systemName: "exclamationmark.shield.fill")
                    .foregroundStyle(Tokens.Status.danger)
                Text("Tracked secret files in git")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Text("\(leaks.count)")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(Tokens.Text.tertiary)
            }
            Text(leaks.prefix(6).joined(separator: ", ") + (leaks.count > 6 ? "…" : ""))
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(Tokens.Text.secondary)
                .lineLimit(2)
            HStack(spacing: Tokens.Space.sm) {
                if let onInstallHook {
                    Button("Install pre-commit hook", action: onInstallHook)
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                }
                if let onFixIgnores {
                    Button("Fix .gitignore", action: onFixIgnores)
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                }
                Text("Then: git rm --cached <file>")
                    .font(.caption2)
                    .foregroundStyle(Tokens.Text.tertiary)
            }
        }
        .padding(Tokens.Space.lg)
        .background(Tokens.Status.danger.opacity(0.08),
                    in: RoundedRectangle(cornerRadius: Tokens.Radius.md, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Tokens.Radius.md, style: .continuous)
                .strokeBorder(Tokens.Status.danger.opacity(0.25), lineWidth: Tokens.Stroke.hairline)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Tracked secret files: \(leaks.joined(separator: ", "))")
    }
}
