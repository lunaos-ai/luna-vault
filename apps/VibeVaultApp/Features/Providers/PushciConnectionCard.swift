import SwiftUI

struct PushciConnectionCard: View {
    @Binding var projectId: String
    @Binding var projectPath: String
    @Binding var allowCI: Bool
    let cloudReady: Bool
    let lastScannedPath: String?
    var onSetup: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.md) {
            header
            VStack(alignment: .leading, spacing: Tokens.Space.xs) {
                Text("Cloud project ID").font(.caption.weight(.semibold)).foregroundStyle(Tokens.Text.secondary)
                TextField("PushCI project UUID", text: $projectId)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(.caption, design: .monospaced))
            }
            Toggle("Also allowlist for CI jobs (ci_secret_names)", isOn: $allowCI)
                .font(.caption)
                .disabled(projectId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            Divider()
            VStack(alignment: .leading, spacing: Tokens.Space.xs) {
                Text("Local project path (fallback)").font(.caption.weight(.semibold))
                    .foregroundStyle(Tokens.Text.secondary)
                TextField("Path to PushCI project root", text: $projectPath)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(.caption, design: .monospaced))
            }
            if let last = lastScannedPath, !last.isEmpty, last != projectPath {
                Button("Use last scanned project") { projectPath = last }
                    .font(.caption)
                    .buttonStyle(.borderless)
            }
            Text(footerLine)
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

    private var header: some View {
        HStack(spacing: Tokens.Space.md) {
            ZStack {
                RoundedRectangle(cornerRadius: Tokens.Radius.sm, style: .continuous)
                    .fill(Tokens.Palette.accent.opacity(0.12))
                    .frame(width: 40, height: 40)
                Image(systemName: usesCloud ? "cloud.fill" : "terminal.fill")
                    .foregroundStyle(Tokens.Palette.accent)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text("pushci.dev").font(.headline)
                Text(statusLine).font(.caption).foregroundStyle(Tokens.Text.secondary)
            }
            Spacer()
            if ready {
                chipLabel("Ready", color: Tokens.Status.success)
            } else if let onSetup {
                Button(action: onSetup) {
                    chipLabel("Setup", color: Tokens.Status.warning)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Setup PushCI")
            } else {
                chipLabel("Setup", color: Tokens.Status.warning)
            }
        }
    }

    private var usesCloud: Bool {
        !projectId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var ready: Bool {
        usesCloud ? cloudReady : (!projectPath.isEmpty)
    }

    private var statusLine: String {
        if usesCloud {
            return cloudReady
                ? "Cloud project secrets via api.pushci.dev"
                : "Needs pushci login JWT (~/.pushci/config.json)"
        }
        if projectPath.isEmpty { return "Enter cloud project ID, or a local project path" }
        return "Local `.pushci/secrets.enc` via PushCI CLI"
    }

    private var footerLine: String {
        if usesCloud {
            return "Auth: PUSHCI_TOKEN or ~/.pushci/config.json. PUT /api/projects/:id/secrets/:name"
        }
        return "Writes to `.pushci/secrets.enc` via `pushci secret`. Requires PushCI CLI on PATH."
    }

    private func chipLabel(_ title: String, color: Color) -> some View {
        Text(title)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, Tokens.Space.sm)
            .padding(.vertical, Tokens.Space.xs)
            .background(color.opacity(0.12), in: Capsule())
            .foregroundStyle(color)
    }
}
