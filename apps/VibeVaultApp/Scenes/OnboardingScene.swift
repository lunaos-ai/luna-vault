import SwiftUI

struct OnboardingScene: View {
    @Binding var done: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.xl) {
            Text("Welcome to vibe-vault")
                .font(.system(size: 28, weight: .semibold))
            Text("Your secrets live in macOS Keychain. Every read is audited per AI agent. No cloud, no account.")
                .foregroundStyle(Tokens.Color.textSecondary)

            VStack(alignment: .leading, spacing: Tokens.Space.md) {
                row(icon: "lock.shield", title: "Local-first", body: "All data in Keychain + local SQLite. No telemetry.")
                row(icon: "eye.fill", title: "Audit per agent", body: "Claude Code, Cursor, Windsurf tagged on every read.")
                row(icon: "magnifyingglass", title: "Auto-detect", body: "Scans wrangler.toml, vercel.json, .env.example, package.json.")
                row(icon: "icloud.and.arrow.up", title: "One-command sync", body: "Push to Cloudflare, Vercel, pushci.dev.")
            }

            HStack {
                Spacer()
                Button("Get started") { done = true }
                    .buttonStyle(.borderedProminent)
                    .tint(Tokens.Color.primary)
                    .controlSize(.large)
            }
        }
        .padding(Tokens.Space.xxl)
        .frame(minWidth: 480, minHeight: 420)
    }

    private func row(icon: String, title: String, body: String) -> some View {
        HStack(alignment: .top, spacing: Tokens.Space.md) {
            Image(systemName: icon)
                .foregroundStyle(Tokens.Color.primary)
                .font(.title2)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: Tokens.Space.xs) {
                Text(title).font(.headline)
                Text(body).foregroundStyle(Tokens.Color.textSecondary)
            }
        }
    }
}
