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
        Form {
            Section {
                Picker("Provider", selection: $selectedProviderId) {
                    ForEach(env.registry.all, id: \.id) { provider in
                        Text(provider.displayName).tag(provider.id)
                    }
                }
            } header: {
                Text("Destination")
            }

            if let provider = env.registry.provider(id: selectedProviderId) {
                Section {
                    ForEach(provider.requiredScopeKeys, id: \.self) { key in
                        TextField(key, text: Binding(
                            get: { scopeFields[key] ?? "" },
                            set: { scopeFields[key] = $0 }
                        ), prompt: Text(key))
                    }
                } header: {
                    Text("Scope")
                } footer: {
                    Text("Provider-specific identifiers required to target the right resource.")
                }

                Section {
                    if env.secrets.isEmpty {
                        Text("Vault is empty. Add or import secrets first.")
                            .foregroundStyle(.secondary)
                    } else {
                        ScrollView {
                            LazyVStack(alignment: .leading, spacing: 0) {
                                ForEach(env.secrets) { secret in
                                    HStack {
                                        Toggle(isOn: Binding(
                                            get: { selectedSecrets.contains(secret.name) },
                                            set: { on in
                                                if on { selectedSecrets.insert(secret.name) }
                                                else { selectedSecrets.remove(secret.name) }
                                            }
                                        )) {
                                            Text(secret.name).font(.system(.body, design: .monospaced))
                                        }
                                    }
                                    .padding(.vertical, 4)
                                }
                            }
                        }
                        .frame(maxHeight: 240)
                    }
                } header: {
                    HStack {
                        Text("Secrets to push")
                        Spacer()
                        Text("\(selectedSecrets.count) selected")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                if let status = status {
                    Section {
                        Text(status).font(.callout)
                    } header: {
                        Text("Result")
                    }
                }
            }
        }
        .formStyle(.grouped)
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
