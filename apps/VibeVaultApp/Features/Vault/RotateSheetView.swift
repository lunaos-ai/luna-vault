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
        VStack(alignment: .leading, spacing: Tokens.Space.lg) {
            Text("Rotate \(secret.name)")
                .font(.system(.title2, design: .rounded).weight(.semibold))
                .foregroundStyle(Tokens.Text.primary)

            ScrollView {
                fields.glassCard()
            }

            actionBar
        }
        .padding(Tokens.Space.xl)
        .frame(width: 480)
        .frame(minHeight: 360)
        .background(CompactLiquidBackdrop())
    }

    private var fields: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.lg) {
            field("New value") {
                SecureField("New value", text: $newValue)
                    .textFieldStyle(.roundedBorder)
                footnote("Audit log records who rotated and when.")
            }

            Divider().overlay(Tokens.Surface.separator)

            field("Cloud sync") {
                Toggle("Also push to a provider", isOn: $alsoPush)
                    .toggleStyle(.switch)
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
                            .textFieldStyle(.roundedBorder)
                        }
                    }
                }
                footnote(alsoPush
                     ? "Vault is updated first; if the push fails, the local change still sticks (you can retry from Providers)."
                     : "Local-only rotation. Push later from Providers if needed.")
            }

            if let status = status {
                Divider().overlay(Tokens.Surface.separator)
                field("Result") {
                    Text(status).font(.callout).foregroundStyle(Tokens.Text.primary)
                }
            }
        }
    }

    @ViewBuilder
    private func field<Content: View>(
        _ title: String, @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: Tokens.Space.sm) {
            Text(title).sectionLabel()
            content()
        }
    }

    private func footnote(_ text: String) -> some View {
        Text(text)
            .font(.footnote)
            .foregroundStyle(Tokens.Text.secondary)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var actionBar: some View {
        HStack {
            Button("Cancel") { isPresented = false }
                .buttonStyle(.glass)
            Spacer()
            Button("Rotate") {
                Task { await perform() }
            }
            .buttonStyle(.glassProminent)
            .keyboardShortcut(.defaultAction)
            .disabled(newValue.isEmpty)
        }
    }

    @MainActor
    private func perform() async {
        await env.rotateSaving(name: secret.name, newValue: newValue)
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
