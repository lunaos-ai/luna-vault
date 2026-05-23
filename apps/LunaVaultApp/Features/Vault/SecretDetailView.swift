import SwiftUI
import VaultCore

struct SecretDetailView: View {
    @EnvironmentObject var env: AppEnvironment
    let secret: Secret
    @State private var revealed = false
    @State private var revealedValue = ""
    @State private var deleteConfirm = false

    var body: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.lg) {
            HStack {
                Text(secret.name).font(.system(.title2, design: .monospaced))
                Spacer()
                Button(role: .destructive) {
                    deleteConfirm = true
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            }

            VStack(alignment: .leading, spacing: Tokens.Space.sm) {
                Text("Value").font(.caption).foregroundStyle(Tokens.Color.textSecondary)
                HStack {
                    Text(revealed ? revealedValue : secret.maskedValue)
                        .font(.system(.body, design: .monospaced))
                        .textSelection(.enabled)
                    Spacer()
                    Button {
                        Task { await reveal() }
                    } label: {
                        Image(systemName: revealed ? "eye.slash" : "eye")
                    }
                    .buttonStyle(.borderless)
                }
                .cardSurface()
            }

            VStack(alignment: .leading, spacing: Tokens.Space.sm) {
                Text("Updated").font(.caption).foregroundStyle(Tokens.Color.textSecondary)
                Text(secret.updatedAt.formatted(date: .abbreviated, time: .standard))
            }

            if let notes = secret.notes, !notes.isEmpty {
                VStack(alignment: .leading, spacing: Tokens.Space.sm) {
                    Text("Notes").font(.caption).foregroundStyle(Tokens.Color.textSecondary)
                    Text(notes)
                }
            }

            Spacer()
        }
        .padding(Tokens.Space.xl)
        .frame(maxWidth: .infinity, alignment: .leading)
        .confirmationDialog(
            "Delete \(secret.name)?",
            isPresented: $deleteConfirm,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) { env.deleteSecret(name: secret.name) }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This removes the secret from your local Keychain. Cloud provider copies are not revoked.")
        }
    }

    private func reveal() async {
        do {
            let fresh = try await env.service.read(name: secret.name, reason: "Reveal \(secret.name)")
            revealedValue = fresh.value
            revealed = true
        } catch {
            env.lastError = "\(error)"
        }
    }
}
