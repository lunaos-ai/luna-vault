import SwiftUI
import VaultCore

struct VercelSettingsSection: View {
    @EnvironmentObject var env: AppEnvironment
    @State private var token = ""
    @State private var tokenSaved = false

    var body: some View {
        Section {
            HStack(spacing: Tokens.Space.sm) {
                Image(systemName: env.hasVercelToken ? "checkmark.circle.fill" : "exclamationmark.circle")
                    .foregroundStyle(env.hasVercelToken ? Tokens.Status.success : Tokens.Status.warning)
                Text(env.hasVercelToken ? "API token configured" : "API token required for sync")
                    .foregroundStyle(Tokens.Text.secondary)
            }
            SecureField("Vercel API token", text: $token, prompt: Text("Paste token"))
                .textFieldStyle(.roundedBorder)
                .font(.system(.body, design: .monospaced))
            HStack {
                Button("Save token") { saveToken() }
                    .buttonStyle(.borderedProminent)
                    .tint(Tokens.Palette.accent)
                    .disabled(token.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                if tokenSaved {
                    Label("Saved", systemImage: "checkmark")
                        .font(.caption)
                        .foregroundStyle(Tokens.Status.success)
                }
            }
            Link(destination: URL(string: "https://vercel.com/account/tokens")!) {
                Label("Create token in Vercel dashboard", systemImage: "arrow.up.right.square")
            }
            .font(.caption)
        } header: {
            Text("Vercel")
        } footer: {
            Text("Stored in Keychain. Needs project env write access.")
        }
    }

    private func saveToken() {
        let trimmed = token.trimmingCharacters(in: .whitespacesAndNewlines)
        env.setVercelToken(trimmed)
        token = ""
        tokenSaved = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { tokenSaved = false }
    }
}
