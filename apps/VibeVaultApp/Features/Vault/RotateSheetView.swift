import SwiftUI
import VaultCore

struct RotateSheetView: View {
    @EnvironmentObject var env: AppEnvironment
    let secret: Secret
    @Binding var isPresented: Bool

    @State private var newValue = ""
    @State private var alsoPush = false
    @State private var providerId = "cloudflare"
    @State private var scope: [String: String] = [:]
    @State private var status: String?

    var body: some View {
        Form {
            Section {
                SecureField("New value", text: $newValue)
            } header: {
                Text("Rotate \(secret.name)")
            } footer: {
                Text("Audit log records who rotated and when.")
            }
            Section {
                Toggle("Also push to a provider", isOn: $alsoPush)
                if alsoPush {
                    Picker("Provider", selection: $providerId) {
                        ForEach(env.registry.all, id: \.id) { Text($0.displayName).tag($0.id) }
                    }
                    if let provider = env.registry.provider(id: providerId) {
                        ForEach(provider.requiredScopeKeys, id: \.self) { key in
                            TextField(key, text: Binding(
                                get: { scope[key] ?? "" },
                                set: { scope[key] = $0 }
                            ), prompt: Text(key))
                        }
                    }
                }
            } header: {
                Text("Cloud sync")
            } footer: {
                Text(alsoPush
                     ? "Vault is updated first; if the push fails, the local change still sticks (you can retry from Providers)."
                     : "Local-only rotation. Push later from Providers if needed.")
            }
            if let status = status {
                Section { Text(status).font(.callout) } header: { Text("Result") }
            }
        }
        .formStyle(.grouped)
        .frame(minWidth: 480, minHeight: 360)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { isPresented = false }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Rotate") {
                    Task { await perform() }
                }
                .keyboardShortcut(.defaultAction)
                .disabled(newValue.isEmpty)
            }
        }
    }

    @MainActor
    private func perform() async {
        await env.rotate(name: secret.name, newValue: newValue)
        status = "Rotated in vault."
        if alsoPush, let provider = env.registry.provider(id: providerId) {
            do {
                let fresh = try await env.service.read(name: secret.name, reason: "Push rotated \(secret.name)")
                let target = ProviderTarget(provider: provider.id, scope: scope)
                let result = try await provider.push(secrets: [fresh], target: target)
                if result.failed.isEmpty {
                    status = "Rotated in vault and pushed to \(provider.displayName)."
                } else {
                    status = "Vault rotated; \(provider.displayName) push failed: \(result.failed.first?.reason ?? "unknown")."
                    return
                }
            } catch {
                status = "Vault rotated; push failed: \(error)"
                return
            }
        }
        isPresented = false
    }
}
