import SwiftUI
import VaultCore

struct SecretDetailActions: View {
    @EnvironmentObject var env: AppEnvironment
    let secret: Secret
    @Binding var showRotateSheet: Bool
    @Binding var deleteConfirm: Bool

    var body: some View {
        HStack(spacing: Tokens.Space.sm) {
            Button { showRotateSheet = true } label: {
                Image(systemName: "arrow.triangle.2.circlepath")
            }
            .buttonStyle(.borderedProminent)
            .help("Rotate value")
            .accessibilityLabel("Rotate value")
            Button { Task { await markRotated() } } label: {
                Image(systemName: "checkmark.circle")
            }
            .help("Records rotation without changing the value.")
            .accessibilityLabel("Mark rotated now")
            Button { Task { await env.duplicateSecret(name: secret.name) } } label: {
                Image(systemName: "square.on.square")
            }
            .help("Duplicate secret as \(secret.name)-copy")
            .accessibilityLabel("Duplicate secret")
            Spacer()
            Button(role: .destructive) { deleteConfirm = true } label: {
                Image(systemName: "trash")
            }
            .help("Delete secret")
            .accessibilityLabel("Delete secret")
        }
    }

    private func markRotated() async {
        do {
            try await env.service.rotate(name: secret.name, newValue: nil)
            env.refresh()
        } catch { env.lastError = "\(error)" }
    }
}
