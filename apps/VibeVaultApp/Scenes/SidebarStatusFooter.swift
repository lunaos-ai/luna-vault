import SwiftUI
import VaultCore

struct SidebarStatusFooter: View {
    @EnvironmentObject var env: AppEnvironment

    var body: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.sm) {
            sessionRow
            sessionTimingRow
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
                    Label("Unlock VibeVault", systemImage: "lock.open.fill")
                        .font(.system(size: 11, weight: .semibold))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(Tokens.Palette.accent)
                .controlSize(.small)
                .help("One approval opens app and CLI access for the selected time.")
                .accessibilityLabel("Unlock for this session")
            }
        }
    }

    @ViewBuilder
    private var sessionTimingRow: some View {
        if env.sessionUnlocked, let expiresAt = env.unlockSessionExpiresAt {
            HStack(spacing: Tokens.Space.xs) {
                Label("Session time", systemImage: "timer")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(Tokens.Text.secondary)
                Spacer(minLength: Tokens.Space.xs)
                Text("\(remainingTime(until: expiresAt)) left, until \(formattedTime(expiresAt))")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(Tokens.Status.success)
                    .lineLimit(1)
            }
            .accessibilityElement(children: .combine)
        } else {
            HStack(spacing: Tokens.Space.xs) {
                Label("Unlock duration", systemImage: "timer")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(Tokens.Text.secondary)
                Spacer(minLength: Tokens.Space.xs)
                Picker("Unlock duration", selection: $env.biometricSessionMinutes) {
                    Text("5 minutes").tag(5.0)
                    Text("15 minutes").tag(15.0)
                    Text("30 minutes").tag(30.0)
                    Text("1 hour").tag(60.0)
                    Text("2 hours").tag(120.0)
                    Text("4 hours").tag(240.0)
                    Text("8 hours").tag(480.0)
                }
                .labelsHidden()
                .pickerStyle(.menu)
                .controlSize(.small)
                .fixedSize()
            }
        }
    }

    private var mcpInstalled: Bool {
        MCPClientID.allCases.contains { MCPClientInstaller.status(of: $0).installed }
    }

    private var sessionCaption: String {
        if env.sessionUnlocked, env.unlockSessionExpiresAt != nil {
            return "Unlocked for all local VibeVault calls"
        }
        if env.sessionUnlocked { return "Unlocked (timed)" }
        return "One approval starts the selected window"
    }

    private func remainingTime(until expiresAt: Date) -> String {
        let seconds = max(0, Int(expiresAt.timeIntervalSinceNow.rounded(.up)))
        let hours = seconds / 3_600
        let minutes = (seconds % 3_600 + 59) / 60
        if hours > 0, minutes > 0 { return "\(hours)h \(minutes)m" }
        if hours > 0 { return "\(hours)h" }
        return "\(minutes)m"
    }

    private func formattedTime(_ date: Date) -> String {
        date.formatted(date: .omitted, time: .shortened)
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
