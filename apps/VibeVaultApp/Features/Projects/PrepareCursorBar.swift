import SwiftUI
import VaultCore

struct PrepareCursorBar: View {
    @EnvironmentObject var env: AppEnvironment
    let projectURL: URL
    var onOpenAIAgents: (() -> Void)?

    @State private var busy = false
    @State private var status: String?

    var body: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.sm) {
            HStack(spacing: Tokens.Space.sm) {
                Image(systemName: "cursorarrow.rays")
                    .foregroundStyle(Tokens.Palette.accent)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Prepare for Cursor")
                        .font(.subheadline.weight(.semibold))
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(Tokens.Text.secondary)
                }
                Spacer()
                if busy {
                    ProgressView().controlSize(.small)
                } else {
                    Button("Prepare") { runPrep() }
                        .buttonStyle(.borderedProminent)
                        .tint(Tokens.Palette.accent)
                        .controlSize(.small)
                }
            }
            if let status {
                Text(status).font(.caption2).foregroundStyle(Tokens.Text.tertiary)
            }
        }
        .padding(Tokens.Space.md)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: Tokens.Radius.md, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Tokens.Radius.md, style: .continuous)
                .strokeBorder(Tokens.Surface.separator.opacity(0.6), lineWidth: Tokens.Stroke.hairline)
        )
    }

    private var subtitle: String {
        let rules = CursorRulesInstaller.isInstalled(projectURL: projectURL)
        if rules { return "Rules present — re-run to refresh skill, MCP, guard" }
        return "Rules + skill + MCP + pre-commit guard"
    }

    private func runPrep() {
        busy = true
        status = nil
        defer { busy = false }
        do {
            let binary = MCPBinaryLocator.resolve()
            let path = FileManager.default.isExecutableFile(atPath: binary) ? binary : nil
            let result = try CursorProjectPrep.prepare(
                projectURL: projectURL,
                mcpBinaryPath: path,
                installGuard: true,
                writeIgnores: true,
                writeAgentsMd: true,
                knownSecrets: Set(env.secrets.map(\.name))
            )
            status = result.messages.joined(separator: " · ")
            env.showToast("Prepared for Cursor")
            onOpenAIAgents?()
        } catch {
            status = "\(error)"
            env.lastError = "\(error)"
        }
    }
}
