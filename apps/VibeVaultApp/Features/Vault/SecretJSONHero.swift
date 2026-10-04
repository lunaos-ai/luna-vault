import SwiftUI
import VaultCore

/// Inset JSON value field for the secret detail hero.
struct SecretJSONHero: View {
    @EnvironmentObject var env: AppEnvironment
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let secret: Secret
    var onEdit: () -> Void
    @State private var revealed = false
    @State private var revealedValue = ""
    @State private var copiedFlash = false

    var body: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.md) {
            HStack(spacing: Tokens.Space.md) {
                Text(revealed ? "JSON" : secret.maskedValue)
                    .font(.system(.title3, design: .monospaced).weight(.medium))
                    .foregroundStyle(Tokens.Text.primary)
                    .lineLimit(1)
                Spacer()
                revealButton
                copyButton
                editButton
            }
            if revealed {
                ScrollView {
                    Text(revealedValue)
                        .font(.system(.body, design: .monospaced).weight(.medium))
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(maxHeight: 280)
                .accessibilityLabel("JSON value")
            }
        }
        .padding(.horizontal, Tokens.Space.lg)
        .padding(.vertical, Tokens.Space.lg)
        .deepInset(radius: Tokens.Radius.md)
        .onChange(of: secret.id) { _, _ in
            revealed = false
            revealedValue = ""
            copiedFlash = false
        }
    }

    private var revealButton: some View {
        Button { Task { await reveal() } } label: {
            Image(systemName: revealed ? "eye.slash" : "eye")
                .font(.system(size: 14, weight: .medium))
        }
        .buttonStyle(.borderless)
        .foregroundStyle(Tokens.Text.secondary)
        .help(revealed ? "Hide JSON" : "Reveal JSON")
        .accessibilityLabel(revealed ? "Hide JSON" : "Reveal JSON")
    }

    private var copyButton: some View {
        Button { Task { await copyValue() } } label: {
            Image(systemName: copiedFlash ? "checkmark" : "doc.on.doc")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(copiedFlash ? Tokens.Status.success : Tokens.Text.secondary)
        }
        .buttonStyle(.borderless)
        .help("Copy JSON")
        .accessibilityLabel(copiedFlash ? "Copied" : "Copy JSON")
    }

    private var editButton: some View {
        Button(action: onEdit) {
            Image(systemName: "pencil")
                .font(.system(size: 14, weight: .medium))
        }
        .buttonStyle(.borderless)
        .foregroundStyle(Tokens.Text.secondary)
        .help("Edit JSON")
        .accessibilityLabel("Edit JSON")
    }

    private func reveal() async {
        if revealed {
            Motion.animate(reduceMotion) { revealed = false; revealedValue = "" }
            return
        }
        do {
            let fresh = try await env.service.read(name: secret.name, reason: "Reveal \(secret.name)")
            Motion.animate(reduceMotion) {
                revealedValue = fresh.value
                revealed = true
            }
        } catch { env.lastError = "\(error)" }
    }

    private func copyValue() async {
        guard await env.copySecret(name: secret.name) else { return }
        Motion.animate(reduceMotion) { copiedFlash = true }
        try? await Task.sleep(nanoseconds: 1_200_000_000)
        Motion.animate(reduceMotion) { copiedFlash = false }
    }
}
