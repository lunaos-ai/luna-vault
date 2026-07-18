import SwiftUI
import VaultCore

struct CloudflareSettingsSection: View {
    @EnvironmentObject var env: AppEnvironment
    @State private var token = ""
    @State private var tokenSaved = false

    var body: some View {
        Section {
            HStack(spacing: Tokens.Space.sm) {
                Image(systemName: env.hasCloudflareToken ? "checkmark.circle.fill" : "exclamationmark.circle")
                    .foregroundStyle(env.hasCloudflareToken ? Tokens.Status.success : Tokens.Status.warning)
                Text(env.hasCloudflareToken ? "API token configured" : "API token required for sync")
                    .foregroundStyle(Tokens.Text.secondary)
            }
            SecureField("Cloudflare API token", text: $token, prompt: Text("Paste token"))
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
            Link(destination: URL(string: "https://dash.cloudflare.com/profile/api-tokens")!) {
                Label("Create token in Cloudflare dashboard", systemImage: "arrow.up.right.square")
            }
            .font(.caption)
        } header: {
            Text("Cloudflare Workers")
        } footer: {
            Text("Stored in Keychain. Needs Workers Scripts:Edit permission for the target script.")
        }
    }

    private func saveToken() {
        let trimmed = token.trimmingCharacters(in: .whitespacesAndNewlines)
        env.setCloudflareToken(trimmed)
        token = ""
        tokenSaved = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { tokenSaved = false }
    }
}
