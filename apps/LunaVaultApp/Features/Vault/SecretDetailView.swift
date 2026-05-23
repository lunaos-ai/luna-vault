import SwiftUI
import VaultCore

struct SecretDetailView: View {
    @EnvironmentObject var env: AppEnvironment
    let secret: Secret
    @State private var revealed = false
    @State private var revealedValue = ""
    @State private var deleteConfirm = false
    @State private var showRotateSheet = false
    @State private var rotateNewValue = ""

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

            statusRow(secret: secret)

            HStack(spacing: Tokens.Space.md) {
                Button {
                    Task { await rotate() }
                } label: {
                    Label("Rotate", systemImage: "arrow.triangle.2.circlepath")
                }
                Button {
                    Task { await markRotated() }
                } label: {
                    Label("Mark rotated", systemImage: "checkmark.circle")
                }
                .help("Records rotation without changing the value (e.g. you rotated at the provider).")
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
        .sheet(isPresented: $showRotateSheet) {
            VStack(alignment: .leading, spacing: Tokens.Space.lg) {
                Text("Rotate \(secret.name)").font(.title3.bold())
                Text("Enter the new value. Audit log records who rotated and when.")
                    .font(.caption)
                    .foregroundStyle(Tokens.Color.textSecondary)
                SecureField("New value", text: $rotateNewValue)
                    .textFieldStyle(.roundedBorder)
                HStack {
                    Button("Cancel") { showRotateSheet = false }
                    Spacer()
                    Button("Rotate") {
                        Task {
                            await env.rotate(name: secret.name, newValue: rotateNewValue)
                            showRotateSheet = false
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Tokens.Color.primary)
                    .disabled(rotateNewValue.isEmpty)
                }
            }
            .padding(Tokens.Space.xl)
            .frame(width: 440)
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

    @ViewBuilder
    private func statusRow(secret: Secret) -> some View {
        HStack(spacing: Tokens.Space.md) {
            if let exp = secret.expiresAt {
                badge(
                    icon: secret.isExpired ? "exclamationmark.triangle.fill" : "clock",
                    text: secret.isExpired ? "Expired \(formatted(exp))" : "Expires \(formatted(exp))",
                    tint: secret.isExpired ? Tokens.Color.danger : Tokens.Color.warning
                )
            }
            if let due = secret.rotationDueAt {
                badge(
                    icon: "arrow.triangle.2.circlepath",
                    text: secret.isRotationDue ? "Rotation due" : "Rotate by \(formatted(due))",
                    tint: secret.isRotationDue ? Tokens.Color.danger : Tokens.Color.textSecondary
                )
            }
        }
    }

    private func badge(icon: String, text: String, tint: Color) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
            Text(text).font(.caption)
        }
        .padding(.horizontal, Tokens.Space.sm)
        .padding(.vertical, 4)
        .background(tint.opacity(0.12))
        .foregroundStyle(tint)
        .clipShape(Capsule())
    }

    private func formatted(_ date: Date) -> String {
        date.formatted(date: .abbreviated, time: .omitted)
    }

    private func rotate() async {
        rotateNewValue = ""
        showRotateSheet = true
    }

    private func markRotated() async {
        do {
            try await env.service.rotate(name: secret.name, newValue: nil)
            env.refresh()
        } catch {
            env.lastError = "\(error)"
        }
    }
}
