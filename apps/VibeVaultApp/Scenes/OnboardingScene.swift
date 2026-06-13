import SwiftUI

struct OnboardingScene: View {
    @Binding var done: Bool

    var body: some View {
        VStack {
            Spacer(minLength: Tokens.Space.xl)
            card
            Spacer(minLength: Tokens.Space.xl)
        }
        .padding(.horizontal, Tokens.Space.xxxl)
        .padding(.vertical, Tokens.Space.xxl)
        .frame(minWidth: 540, minHeight: 480)
        .background(LiquidBackdrop())
    }

    private var card: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.xxl) {
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
                    .accessibilityHidden(true)
                    Text("Vibe Vault")
                        .font(.system(size: 38, weight: .semibold))
                        .tracking(-1.2)
                }
                Text("Secrets that live in your Keychain. Audited per AI agent. No cloud.")
                    .font(.title3.weight(.regular))
                    .foregroundStyle(Tokens.Text.secondary)
                    .frame(maxWidth: 540, alignment: .leading)
                    .lineSpacing(2)
            }

            VStack(alignment: .leading, spacing: Tokens.Space.lg) {
                row(
                    icon: "lock.shield",
                    title: "Local-first",
                    body: "Keychain + SQLite on disk. No telemetry, no account."
                )
                row(
                    icon: "eye",
                    title: "Audit per agent",
                    body: "Claude Code, Cursor, Windsurf tagged on every read."
                )
                row(
                    icon: "magnifyingglass",
                    title: "Auto-detect",
                    body: "Scans wrangler.toml, vercel.json, .env.example, package.json."
                )
                row(
                    icon: "icloud.and.arrow.up",
                    title: "One-command sync",
                    body: "Push to Cloudflare, Vercel, pushci.dev."
                )
            }

            HStack {
                Spacer()
                Button("Get started") { done = true }
                    .buttonStyle(.glassProminent)
                    .controlSize(.large)
                    .keyboardShortcut(.defaultAction)
            }
        }
        .glassCard(radius: Tokens.Radius.lg, padding: Tokens.Space.xxl, elevation: .lifted)
        .frame(maxWidth: 600)
    }

    private func row(icon: String, title: String, body: String) -> some View {
        HStack(alignment: .top, spacing: Tokens.Space.lg) {
            Image(systemName: icon)
                .foregroundStyle(Tokens.Palette.accent)
                .font(.title2.weight(.regular))
                .frame(width: 32, alignment: .leading)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.headline)
                Text(body).foregroundStyle(Tokens.Text.secondary)
            }
        }
    }
}
