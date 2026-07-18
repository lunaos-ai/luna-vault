import SwiftUI
import VaultCore

struct SidebarStatusFooter: View {
    @EnvironmentObject var env: AppEnvironment

    var body: some View {
        VStack(spacing: Tokens.Space.sm) {
            HStack(spacing: Tokens.Space.md) {
                footerDot(
                    ok: env.biometricStatus.lowercased().contains("unlock") || env.biometricStatus == "Idle",
                    label: "Session"
                )
                footerDot(ok: env.hasCloudflareToken, label: "CF")
                footerDot(ok: mcpInstalled, label: "MCP")
            }
            HStack {
                Text(sessionLabel)
                    .font(.system(size: 10))
                    .foregroundStyle(Tokens.Text.tertiary)
                    .lineLimit(1)
                Spacer()
                if env.isTeamLicensed {
                    Text("Team")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(Tokens.Palette.accent)
                }
                Text("v0.1")
                    .font(.system(size: 10))
                    .foregroundStyle(Tokens.Text.tertiary)
            }
        }
        .padding(.horizontal, Tokens.Space.md)
        .padding(.vertical, Tokens.Space.sm)
        .background(.thinMaterial)
    }

    private var mcpInstalled: Bool {
        MCPClientID.allCases.contains { MCPClientInstaller.status(of: $0).installed }
    }

    private var sessionLabel: String {
        if env.biometricStatus.lowercased().contains("unlock") || env.biometricStatus == "Idle" {
            return "Unlocked"
        }
        return "Touch ID required"
    }

    private func footerDot(ok: Bool, label: String) -> some View {
        VStack(spacing: 2) {
            Circle()
                .fill(ok ? Tokens.Status.success : Tokens.Text.tertiary.opacity(0.5))
                .frame(width: 6, height: 6)
            Text(label)
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(Tokens.Text.tertiary)
        }
        .frame(maxWidth: .infinity)
    }
}
