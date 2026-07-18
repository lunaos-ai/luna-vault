import SwiftUI
import VaultCore

struct VaultOverviewView: View {
    @EnvironmentObject var env: AppEnvironment
    var onScan: () -> Void
    var onImport: () -> Void
    var onCloudflare: () -> Void
    var onAIAgents: () -> Void
    var onAudit: () -> Void
    var onAdd: () -> Void

    private var health: VaultHealth { VaultHealth(secrets: env.secrets) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Tokens.Space.xxxl) {
                welcomeHero.appearFade()
                if health.attentionCount > 0 { attentionBanner.appearFade() }
                quickActions.appearFade()
                RecentActivityFeed(events: env.auditEvents, onViewAll: onAudit).appearFade()
            }
            .padding(Tokens.Space.xxxl)
            .frame(maxWidth: 720, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
        .background(PremiumBackdrop())
        .navigationTitle("Overview")
        .task { env.refreshAudit() }
    }

    private var welcomeHero: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.md) {
            Text(greeting)
                .font(.system(size: 34, weight: .semibold))
                .tracking(-0.8)
                .foregroundStyle(Tokens.Text.primary)
            Text(health.summaryLine)
                .font(.title3)
                .foregroundStyle(Tokens.Text.secondary)
            HStack(spacing: Tokens.Space.sm) {
                statusChip(
                    env.sessionUnlocked,
                    label: env.sessionUnlocked ? "Session unlocked" : "Locked",
                    icon: env.sessionUnlocked ? "lock.open.fill" : "lock.fill"
                )
                statusChip(env.hasCloudflareToken, label: "Cloudflare", icon: "cloud.fill")
                statusChip(mcpReady, label: "MCP", icon: "sparkles")
            }
            .padding(.top, Tokens.Space.xs)
        }
    }

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        if hour < 12 { return "Good morning" }
        if hour < 17 { return "Good afternoon" }
        return "Good evening"
    }

    private var mcpReady: Bool {
        MCPClientID.allCases.contains { MCPClientInstaller.status(of: $0).installed }
    }

    private var attentionBanner: some View {
        HStack(spacing: Tokens.Space.sm) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(Tokens.Status.warning)
            Text(attentionText)
                .font(.subheadline)
                .foregroundStyle(Tokens.Text.primary)
            Spacer()
        }
        .padding(Tokens.Space.lg)
        .background(Tokens.Status.warning.opacity(0.08), in: RoundedRectangle(cornerRadius: Tokens.Radius.md, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Tokens.Radius.md, style: .continuous)
                .strokeBorder(Tokens.Status.warning.opacity(0.2), lineWidth: Tokens.Stroke.hairline)
        )
    }

    private var attentionText: String {
        var parts: [String] = []
        let h = health
        if h.expired > 0 { parts.append("\(h.expired) expired") }
        if h.rotateDue > 0 { parts.append("\(h.rotateDue) due to rotate") }
        if h.expiringSoon > 0 { parts.append("\(h.expiringSoon) expiring soon") }
        return parts.joined(separator: ", ")
    }

    private var quickActions: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.md) {
            Text("Quick actions").font(.headline)
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: Tokens.Space.md) {
                QuickActionCard(
                    icon: "plus.circle.fill", title: "New secret",
                    subtitle: "Add to vault", tint: Tokens.Palette.accent, action: onAdd
                )
                QuickActionCard(
                    icon: "folder.badge.questionmark", title: "Scan project",
                    subtitle: "Find missing env vars", tint: Tokens.Palette.accent, action: onScan
                )
                QuickActionCard(
                    icon: "square.and.arrow.down", title: "Import",
                    subtitle: "Clipboard, dotenv, shell", tint: Tokens.Palette.mint, action: onImport
                )
                QuickActionCard(
                    icon: "cloud.fill", title: "Cloudflare",
                    subtitle: "Push Worker secrets", tint: Tokens.Status.info, action: onCloudflare
                )
                QuickActionCard(
                    icon: "sparkles", title: "AI Agents",
                    subtitle: "MCP for Cursor & VS Code", tint: Tokens.Palette.accent, action: onAIAgents
                )
            }
        }
    }

    private func statusChip(_ ok: Bool, label: String, icon: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon).font(.caption2)
            Text(label).font(.caption2.weight(.medium))
        }
        .padding(.horizontal, Tokens.Space.sm)
        .padding(.vertical, Tokens.Space.xs)
        .background(
            (ok ? Tokens.Status.success : Tokens.Text.tertiary).opacity(0.12),
            in: Capsule()
        )
        .foregroundStyle(ok ? Tokens.Status.success : Tokens.Text.tertiary)
    }
}
