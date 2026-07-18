import SwiftUI
import VaultCore

/// Reveal / copy controls for the secret value (Touch ID gated via VaultService).
struct SecretValueRow: View {
    @EnvironmentObject var env: AppEnvironment
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let secret: Secret
    @State private var revealed = false
    @State private var revealedValue = ""
    @State private var copiedFlash = false

    var body: some View {
        HStack(spacing: Tokens.Space.md) {
            Text(revealed ? revealedValue : secret.maskedValue)
                .font(.system(.title3, design: .monospaced).weight(.medium))
                .textSelection(.enabled)
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentTransition(.opacity)
                .animation(Motion.value(reduceMotion, Motion.soft), value: revealed)
                .animation(Motion.value(reduceMotion, Motion.soft), value: secret.id)
            revealButton
            copyButton
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
                .contentTransition(.symbolEffect(.replace))
        }
        .buttonStyle(.borderless)
        .foregroundStyle(Tokens.Text.secondary)
        .pressableScale()
        .help(revealed ? "Hide value" : (env.sessionUnlocked ? "Reveal value" : "Reveal value (Touch ID)"))
        .accessibilityLabel(revealed ? "Hide value" : "Reveal value")
    }

    private var copyButton: some View {
        Button { Task { await copy() } } label: {
            Image(systemName: copiedFlash ? "checkmark" : "doc.on.doc")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(copiedFlash ? Tokens.Status.success : Tokens.Text.secondary)
                .contentTransition(.symbolEffect(.replace))
                .bounceIfMotion(copiedFlash)
        }
        .buttonStyle(.borderless)
        .pressableScale()
        .help(env.sessionUnlocked ? "Copy value" : "Copy value (Touch ID)")
        .accessibilityLabel(copiedFlash ? "Copied" : "Copy value")
    }

    private func reveal() async {
        if revealed {
            Motion.animate(reduceMotion) { revealed = false; revealedValue = "" }
            Feedback.play(.tick, soundsEnabled: env.uiSoundsEnabled)
            return
        }
        do {
            let fresh = try await env.service.read(name: secret.name, reason: "Reveal \(secret.name)")
            Motion.animate(reduceMotion) {
                revealedValue = fresh.value
                revealed = true
            }
            Feedback.play(.select, soundsEnabled: env.uiSoundsEnabled)
        } catch { env.lastError = "\(error)" }
    }

    private func copy() async {
        guard await env.copySecret(name: secret.name) else { return }
        Motion.animate(reduceMotion) { copiedFlash = true }
        try? await Task.sleep(nanoseconds: 1_200_000_000)
        Motion.animate(reduceMotion) { copiedFlash = false }
    }
}
