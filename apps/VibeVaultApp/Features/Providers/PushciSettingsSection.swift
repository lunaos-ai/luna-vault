import SwiftUI
import VaultCore

struct PushciSettingsSection: View {
    var body: some View {
        Section {
            Label("Cloud + local sync", systemImage: "cloud")
                .foregroundStyle(Tokens.Text.secondary)
            Text("Cloud: onboard vault secrets into a PushCI project via PUT /api/projects/:id/secrets/:name (JWT from pushci login). Local: `pushci secret set` into `.pushci/secrets.enc`.")
                .font(.caption)
                .foregroundStyle(Tokens.Text.secondary)
            Link(destination: URL(string: "https://pushci.dev/docs")!) {
                Label("PushCI docs", systemImage: "arrow.up.right.square")
            }
            .font(.caption)
        } header: {
            Text("pushci.dev")
        } footer: {
            Text("Auth order: PUSHCI_TOKEN → vault prefs → ~/.pushci/config.json. Providers → PushCI sets project_id or local path.")
        }
    }
}
