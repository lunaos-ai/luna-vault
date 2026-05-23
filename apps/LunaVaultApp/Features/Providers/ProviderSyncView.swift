import SwiftUI
import VaultCore

struct ProviderSyncView: View {
    @EnvironmentObject var env: AppEnvironment
    @State private var selectedProviderId = "cloudflare"
    @State private var scopeFields: [String: String] = [:]
    @State private var selectedSecrets: Set<String> = []
    @State private var pushing = false
    @State private var status: String?

    var body: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.lg) {
            Text("Provider sync").font(.title2.bold())

            Picker("Provider", selection: $selectedProviderId) {
                ForEach(env.registry.all, id: \.id) { provider in
                    Text(provider.displayName).tag(provider.id)
                }
            }
            .pickerStyle(.segmented)

            if let provider = env.registry.provider(id: selectedProviderId) {
                scopeFieldsView(for: provider)
                secretSelectionView()
                HStack {
                    Spacer()
                    Button {
                        Task { await push(provider: provider) }
                    } label: {
                        Label(pushing ? "Pushing…" : "Push to \(provider.displayName)",
                              systemImage: "icloud.and.arrow.up")
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Tokens.Color.cta)
                    .disabled(pushing || selectedSecrets.isEmpty)
                }
                if let status = status {
                    Text(status).foregroundStyle(Tokens.Color.textSecondary)
                }
            }
            Spacer()
        }
        .padding(Tokens.Space.xl)
    }

    private func scopeFieldsView(for provider: SecretProvider) -> some View {
        VStack(alignment: .leading, spacing: Tokens.Space.sm) {
            Text("Scope").font(.caption).foregroundStyle(Tokens.Color.textSecondary)
            ForEach(provider.requiredScopeKeys, id: \.self) { key in
                TextField(key, text: Binding(
                    get: { scopeFields[key] ?? "" },
                    set: { scopeFields[key] = $0 }
                ))
                .textFieldStyle(.roundedBorder)
            }
        }
    }

    private func secretSelectionView() -> some View {
        VStack(alignment: .leading, spacing: Tokens.Space.sm) {
            Text("Secrets to push (\(selectedSecrets.count))")
                .font(.caption).foregroundStyle(Tokens.Color.textSecondary)
            List(env.secrets, selection: $selectedSecrets) { secret in
                Text(secret.name).font(.system(.body, design: .monospaced))
                    .tag(secret.name)
            }
            .frame(minHeight: 180)
        }
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
            status = "pushed \(result.pushed.count) · failed \(result.failed.count)"
        } catch {
            status = "error: \(error)"
        }
    }
}
