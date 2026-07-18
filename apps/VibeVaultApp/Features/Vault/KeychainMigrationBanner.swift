import SwiftUI
import VaultCore

/// Moves secrets still in macOS Keychain into the local vault (one password sheet each).
struct KeychainMigrationBanner: View {
    @EnvironmentObject var env: AppEnvironment
    @State private var pending = 0
    @State private var busy = false
    @State private var didAutoStart = false

    var body: some View {
        Group {
            if pending > 0 {
                HStack(alignment: .top, spacing: Tokens.Space.md) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(Tokens.Status.warning)
                    VStack(alignment: .leading, spacing: Tokens.Space.xs) {
                        Text("\(pending) secrets still use Keychain")
                            .font(.subheadline.weight(.semibold))
                        Text("Allow each login-password prompt once. Then reveal uses Touch ID only.")
                            .font(.caption)
                            .foregroundStyle(Tokens.Text.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 0)
                    if busy {
                        ProgressView()
                            .controlSize(.small)
                    }
                }
                .padding(Tokens.Space.md)
                .background(Tokens.Surface.elevated)
                .clipShape(RoundedRectangle(cornerRadius: Tokens.Radius.md, style: .continuous))
            }
        }
        .task {
            refreshCount()
            guard pending > 0, !didAutoStart else { return }
            didAutoStart = true
            await migrate()
        }
    }

    private func refreshCount() {
        pending = env.legacyKeychainCount()
    }

    @MainActor
    private func migrate() async {
        busy = true
        defer { busy = false }
        let service = env.service
        let result = await Task.detached(priority: .userInitiated) {
            service.migrateLegacyKeychain()
        }.value
        refreshCount()
        env.refresh()
        if result.failed.isEmpty {
            env.showToast("Moved secrets to local vault", feedback: .success)
        } else if result.ok > 0 {
            env.showToast(
                "Moved \(result.ok); \(result.failed.count) still need Allow. Open Vault again",
                feedback: .caution
            )
        }
    }
}
