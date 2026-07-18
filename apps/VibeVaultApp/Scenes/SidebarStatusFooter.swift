import SwiftUI
import VaultCore

struct SidebarStatusFooter: View {
    @EnvironmentObject var env: AppEnvironment

    var body: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.sm) {
            sessionRow
            HStack(spacing: Tokens.Space.md) {
                footerDot(ok: env.sessionUnlocked, label: "Session")
                footerDot(ok: env.hasCloudflareToken, label: "CF")
                footerDot(ok: mcpInstalled, label: "MCP")
            }
            HStack {
                Text(sessionCaption)
                    .font(.system(size: 10))
                    .foregroundStyle(Tokens.Text.tertiary)
                    .lineLimit(1)
                    .accessibilityLabel(sessionCaption)
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

    private var sessionRow: some View {
        Group {
            if env.sessionUnlocked && env.trustSession {
                Button(role: .destructive) { env.lockSession() } label: {
                    Label("Lock session", systemImage: "lock.fill")
                        .font(.system(size: 11, weight: .semibold))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .help("Clear session trust and require Touch ID again.")
                .accessibilityLabel("Lock session")
            } else {
                Button {
                    Task { await env.unlockForSession() }
                } label: {
                    Label("Unlock for this session", systemImage: "lock.open.fill")
                        .font(.system(size: 11, weight: .semibold))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(Tokens.Palette.accent)
                .controlSize(.small)
                .help("One Touch ID — then reveal and copy without re-prompting until quit.")
                .accessibilityLabel("Unlock for this session")
            }
        }
    }

    private var mcpInstalled: Bool {
        MCPClientID.allCases.contains { MCPClientInstaller.status(of: $0).installed }
    }

    private var sessionCaption: String {
        if env.sessionUnlocked && env.trustSession { return "Unlocked until quit" }
        if env.sessionUnlocked { return "Unlocked (timed)" }
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
