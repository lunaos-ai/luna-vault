import SwiftUI
import VaultCore

struct AIAgentClientRow: View {
    let client: MCPClientID
    let status: MCPInstallStatus?
    let binaryReady: Bool
    let onInstall: () -> Void
    let onRemove: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.sm) {
            HStack(spacing: Tokens.Space.md) {
                clientIcon
                VStack(alignment: .leading, spacing: 2) {
                    Text(client.displayName).font(.subheadline.weight(.semibold))
                    Text(client.configHint)
                        .font(.caption2)
                        .foregroundStyle(Tokens.Text.tertiary)
                        .lineLimit(1)
                }
                Spacer()
                statusChip
            }
            HStack(spacing: Tokens.Space.sm) {
                Button(status?.installed == true ? "Reinstall" : "Install", action: onInstall)
                    .buttonStyle(.bordered)
                    .disabled(!binaryReady)
                if status?.installed == true {
                    Button("Remove", role: .destructive, action: onRemove)
                        .buttonStyle(.bordered)
                }
            }
        }
        .padding(Tokens.Space.md)
        .cardSurface(radius: Tokens.Radius.md)
    }

    @ViewBuilder
    private var clientIcon: some View {
        ZStack {
            RoundedRectangle(cornerRadius: Tokens.Radius.sm, style: .continuous)
                .fill(Tokens.Palette.accent.opacity(0.1))
                .frame(width: 36, height: 36)
            Image(systemName: iconName)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(Tokens.Palette.accent)
        }
    }

    private var iconName: String {
        switch client {
        case .cursor: return "cursorarrow.rays"
        case .vscode: return "chevron.left.forwardslash.chevron.right"
        case .devin: return "cpu"
        case .claudeCode, .claudeDesktop: return "sparkles"
        case .windsurf: return "wind"
        }
    }

    @ViewBuilder
    private var statusChip: some View {
        if let status {
            if status.installed {
                Text("Connected").font(.caption2.weight(.semibold)).tintedChip(Tokens.Status.success)
            } else if status.parentDirExists {
                Text("Detected").font(.caption).foregroundStyle(Tokens.Text.secondary)
            } else {
                Text("Not installed").font(.caption).foregroundStyle(Tokens.Text.tertiary)
            }
        }
    }
}
