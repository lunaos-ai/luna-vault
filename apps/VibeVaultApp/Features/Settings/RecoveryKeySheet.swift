import AppKit
import SwiftUI
import VaultCore

struct RecoveryKeySheet: View {
    @Environment(\.dismiss) private var dismiss
    let recoveryKey: String
    let installsKey: Bool
    let onInstall: () -> Void
    @State private var hasSavedKey = false

    var body: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.lg) {
            Label("Vibe Vault Recovery Key", systemImage: "key.fill")
                .font(.title2.weight(.semibold))

            Text(installsKey
                ? "This key can unlock future encrypted backups if the sync passphrase is lost. Vibe Vault cannot recover it for you."
                : "This key unlocks backups protected after it was enabled.")
                .foregroundStyle(Tokens.Text.secondary)

            Text(recoveryKey)
                .font(.system(.body, design: .monospaced).weight(.semibold))
                .textSelection(.enabled)
                .padding(Tokens.Space.md)
                .frame(maxWidth: .infinity, alignment: .leading)
                .deepInset()

            HStack {
                Button {
                    copyRecoveryKey()
                    hasSavedKey = true
                } label: {
                    Label("Copy", systemImage: "doc.on.doc")
                }

                Button {
                    exportRecoveryKit()
                } label: {
                    Label("Export recovery kit...", systemImage: "square.and.arrow.down")
                }

                Spacer()

                Button("Done") { dismiss() }
                if installsKey {
                    Button("I saved this key") { onInstall() }
                        .buttonStyle(.borderedProminent)
                        .disabled(!hasSavedKey)
                }
            }
        }
        .padding(Tokens.Space.xl)
        .frame(width: 620)
    }

    private func exportRecoveryKit() {
        let panel = NSSavePanel()
        panel.title = "Export Vibe Vault recovery kit"
        panel.nameFieldStringValue = "VibeVault-Recovery-Kit.txt"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        let body = """
        VIBE VAULT RECOVERY KIT

        Recovery key:
        \(recoveryKey)

        Use this key in Vibe Vault > Cloud Sync > Restore with recovery key.
        Store this file separately from your encrypted .vvsync backups.
        Anyone with this key and a protected backup can read that backup.
        """
        do {
            try Data(body.utf8).write(to: url, options: .atomic)
            try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
            hasSavedKey = true
        } catch {
            NSAlert(error: error).runModal()
        }
    }

    private func copyRecoveryKey() {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(recoveryKey, forType: .string)
        let changeCount = pasteboard.changeCount
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 60_000_000_000)
            guard pasteboard.changeCount == changeCount,
                  pasteboard.string(forType: .string) == recoveryKey else { return }
            pasteboard.clearContents()
        }
    }
}
