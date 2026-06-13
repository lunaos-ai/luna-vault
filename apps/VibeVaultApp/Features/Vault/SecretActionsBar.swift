import SwiftUI
import VaultCore

/// Action row for a secret's detail pane. Split out of SecretDetailView to keep
/// each file within the 200-line cap.
struct SecretActionsBar: View {
    @EnvironmentObject var env: AppEnvironment
    let secret: Secret
    @Binding var showRotate: Bool
    @Binding var showHistory: Bool
    @Binding var showExport: Bool
    @Binding var deleteConfirm: Bool

    var body: some View {
        HStack(spacing: Tokens.Space.sm) {
            Button { showRotate = true } label: {
                Label("Rotate value…", systemImage: "arrow.triangle.2.circlepath")
            }
            .buttonStyle(.glassProminent)

            Button { showHistory = true } label: {
                Label("History", systemImage: "clock.arrow.circlepath")
            }
            .buttonStyle(.glass)
            .help("View and restore previous values.")

            Button { showExport = true } label: {
                Label("Export .env", systemImage: "square.and.arrow.down")
            }
            .buttonStyle(.glass)
            .help("Write this secret to a project .env file.")

            Button { Task { await markRotated() } } label: {
                Label("Mark rotated", systemImage: "checkmark.circle")
            }
            .buttonStyle(.glass)
            .help("Records rotation without changing the value.")

            Spacer()
            Button(role: .destructive) { deleteConfirm = true } label: {
                Label("Delete", systemImage: "trash")
            }
            .buttonStyle(.glass(tint: Tokens.Status.danger))
        }
    }

    private func markRotated() async {
        do {
            try await env.service.rotate(name: secret.name, newValue: nil)
            env.refresh()
        } catch { env.lastError = "\(error)" }
    }
}
