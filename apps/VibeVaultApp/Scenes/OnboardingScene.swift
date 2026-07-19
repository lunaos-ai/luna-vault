import SwiftUI
import VaultCore

struct OnboardingScene: View {
    @EnvironmentObject var env: AppEnvironment
    var onScanProject: () -> Void
    var onOpenVault: () -> Void
    var onConnectAgents: () -> Void

    @State private var installStatus: String?

    var body: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.xxl) {
            header
            featureRows
            agentStrip
            footerActions
        }
        .padding(.horizontal, Tokens.Space.xxxl)
        .padding(.vertical, Tokens.Space.xxl)
        .frame(minWidth: 560, minHeight: 560)
        .background(PremiumBackdrop())
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.md) {
            HStack(spacing: Tokens.Space.md) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Tokens.Palette.accent.opacity(0.14))
                        .frame(width: 44, height: 44)
                    Image(systemName: "key.fill")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(Tokens.Palette.accent)
                }
                Text("Vibe Vault")
                    .font(.system(size: 34, weight: .semibold))
                    .tracking(-0.8)
            }
            Text("Local secrets for the AI era. Encrypted vault, per-agent audit, MCP for Cursor and VS Code.")
                .font(.title3.weight(.regular))
                .foregroundStyle(Tokens.Text.secondary)
                .frame(maxWidth: 520, alignment: .leading)
                .lineSpacing(2)
        }
    }

    private var featureRows: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.lg) {
            row(icon: "sparkles", title: "AI-native MCP",
                body: "Cursor, VS Code Copilot, Devin, Claude Code. Opt-in per secret.")
            row(icon: "touchid", title: "Touch ID on every read",
                body: "Humans confirm in the app. Agents use MCP with audit only.")
            row(icon: "cloud.fill", title: "Cloudflare Workers",
                body: "Scan wrangler.toml, import dotenv, push secrets in one flow.")
            row(icon: "eye", title: "Audit per agent",
                body: "See which agent read which secret, when, and from which project.")
        }
    }

    private var agentStrip: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.sm) {
            Text("Quick setup").font(.subheadline.weight(.semibold))
            HStack(spacing: Tokens.Space.sm) {
                Button { quickInstall([.cursor, .vscode]) } label: {
                    Label("Install Cursor + VS Code", systemImage: "square.and.arrow.down")
                }
                .buttonStyle(.bordered)
                Button { quickInstallSkill() } label: {
                    Label("Install agent skill", systemImage: "text.book.closed")
                }
                .buttonStyle(.bordered)
                Button(action: onConnectAgents) {
                    Label("AI Agents settings", systemImage: "sparkles")
                }
                .buttonStyle(.bordered)
            }
            if let installStatus {
                Text(installStatus).font(.caption).foregroundStyle(Tokens.Text.secondary)
            }
        }
    }

    private var footerActions: some View {
        HStack(spacing: Tokens.Space.md) {
            Button("Scan a project", action: onScanProject).buttonStyle(.bordered)
            Button { Task { await env.testBiometric() } } label: {
                Label("Test Touch ID", systemImage: "touchid")
            }
            .buttonStyle(.bordered)
            Spacer()
            Button("Open vault", action: onOpenVault)
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .keyboardShortcut(.defaultAction)
        }
    }

    private func row(icon: String, title: String, body: String) -> some View {
        HStack(alignment: .top, spacing: Tokens.Space.lg) {
            Image(systemName: icon)
                .foregroundStyle(Tokens.Text.primary)
                .font(.title2.weight(.regular))
                .frame(width: 32, alignment: .leading)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.headline)
                Text(body).foregroundStyle(Tokens.Text.secondary)
            }
        }
    }

    private func quickInstall(_ clients: [MCPClientID]) {
        let binary = MCPBinaryLocator.resolve()
        guard FileManager.default.isExecutableFile(atPath: binary) else {
            installStatus = "Build the app first, then reinstall MCP clients."
            return
        }
        do {
            for client in clients { try MCPClientInstaller.install(client: client, binaryPath: binary) }
            installStatus = "Installed MCP for \(clients.map(\.displayName).joined(separator: " and "))."
        } catch {
            installStatus = "\(error)"
        }
    }

    private func quickInstallSkill() {
        do {
            try AgentSkillInstaller.installAll()
            installStatus = "Agent skill installed for Cursor, Claude, and Devin."
        } catch {
            installStatus = "\(error)"
        }
    }
}
