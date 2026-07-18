import SwiftUI

struct PushciSettingsSection: View {
    var body: some View {
        Section {
            Label("Local CLI sync", systemImage: "terminal")
                .foregroundStyle(Tokens.Text.secondary)
            Text("PushCI secrets live in `.pushci/secrets.enc` per project. Vibe Vault calls `pushci secret set/get` — no cloud token required for local sync.")
                .font(.caption)
                .foregroundStyle(Tokens.Text.secondary)
            Link(destination: URL(string: "https://pushci.dev/docs")!) {
                Label("PushCI docs", systemImage: "arrow.up.right.square")
            }
            .font(.caption)
        } header: {
            Text("pushci.dev")
        } footer: {
            Text("Optional: set PUSHCI_TOKEN in shell for future cloud API. Providers → PushCI picks the project path.")
        }
    }
}
