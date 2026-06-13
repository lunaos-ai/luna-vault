import SwiftUI
import VaultCore

struct ProviderSyncView: View {
    @EnvironmentObject var env: AppEnvironment
    @State private var selectedProviderId = "cloudflare"
    @State private var scopeFields: [String: String] = [:]
    @State private var selectedSecrets: Set<String> = []
    @State private var secretSearch = ""
    @State private var pushing = false
    @State private var status: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Tokens.Space.xl) {
                destinationCard
                if let provider = env.registry.provider(id: selectedProviderId) {
                    scopeCard(provider)
                    secretsCard
                    if let status = status { resultCard(status) }
                }
            }
            .padding(Tokens.Space.xxl)
            .frame(maxWidth: 760)
            .frame(maxWidth: .infinity)
        }
        .background(LiquidBackdrop())
        .navigationTitle("Provider Sync")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    if let provider = env.registry.provider(id: selectedProviderId) {
                        Task { await push(provider: provider) }
                    }
                } label: {
                    Label(pushing ? "Pushing…" : "Push", systemImage: "icloud.and.arrow.up")
                }
                .disabled(pushing || selectedSecrets.isEmpty)
            }
        }
    }

    private var destinationCard: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.md) {
            Text("Destination").sectionLabel()
            Picker("Provider", selection: $selectedProviderId) {
                ForEach(env.registry.all, id: \.id) { provider in
                    Text(provider.displayName).tag(provider.id)
                }
            }
        }
        .glassCard()
    }

    private func scopeCard(_ provider: SecretProvider) -> some View {
        VStack(alignment: .leading, spacing: Tokens.Space.md) {
            Text("Scope").sectionLabel()
            ForEach(provider.requiredScopeKeys, id: \.self) { key in
                TextField(key, text: Binding(
                    get: { scopeFields[key] ?? "" },
                    set: { scopeFields[key] = $0 }
                ), prompt: Text(key))
            }
            Text("Provider-specific identifiers required to target the right resource.")
                .font(.caption)
                .foregroundStyle(Tokens.Text.secondary)
        }
        .glassCard()
    }

    private var secretsCard: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.md) {
            HStack {
                Text("Secrets to push").sectionLabel()
                Spacer()
                Text("\(selectedSecrets.count) selected")
                    .font(.caption)
                    .foregroundStyle(Tokens.Text.secondary)
            }
            ProviderSecretPicker(
                secrets: env.secrets,
                secretSearch: $secretSearch,
                selectedSecrets: $selectedSecrets
            )
        }
        .glassCard()
    }

    private func resultCard(_ status: String) -> some View {
        VStack(alignment: .leading, spacing: Tokens.Space.md) {
            Text("Result").sectionLabel()
            Text(status).font(.callout)
        }
        .glassCard()
    }

    @MainActor
    private func push(provider: SecretProvider) async {
        pushing = true
        status = nil
        defer { pushing = false }
        do {
            var secrets: [Secret] = []
            for name in selectedSecrets {
                let s = try await env.service.read(name: name, reason: "Push \(name) to \(provider.displayName)")
                secrets.append(s)
            }
            let target = ProviderTarget(provider: provider.id, scope: scopeFields)
            let result = try await provider.push(secrets: secrets, target: target)
            status = "Pushed \(result.pushed.count) · failed \(result.failed.count)"
        } catch {
            status = "Error: \(error)"
        }
    }
}
