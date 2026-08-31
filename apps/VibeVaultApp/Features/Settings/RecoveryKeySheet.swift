import AppKit
import SwiftUI
import VaultCore

struct RecoveryKeySheet: View {
    @Environment(\.dismiss) private var dismiss
    let recoveryKey: String
    let fingerprint: String
    let createdAt: Date
    let installsKey: Bool
    let currentFingerprint: String?
    let onInstall: () -> Void
    @State private var hasSavedKey = false

    var body: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.lg) {
            Label("Vibe Vault Recovery Key", systemImage: "key.fill")
                .font(.title2.weight(.semibold))

            Text(installsKey
                ? "This key can unlock future encrypted backups if the sync passphrase is lost. Vibe Vault cannot recover it for you."
                : "This key unlocks backups that were protected with it.")
                .foregroundStyle(Tokens.Text.secondary)

            LabeledContent("Fingerprint", value: fingerprint)
            LabeledContent(
                "Created",
                value: createdAt.formatted(date: .abbreviated, time: .shortened)
            )

            if let currentFingerprint, installsKey {
                Text("Current active key: \(currentFingerprint). Existing backups still require their original keys. The current key will remain available for restores.")
                    .foregroundStyle(Tokens.Status.warning)
                    .textSelection(.enabled)
            }

            Text(recoveryKey)
                .font(.system(.body, design: .monospaced).weight(.semibold))
                .textSelection(.enabled)
                .padding(Tokens.Space.md)
                .frame(maxWidth: .infinity, alignment: .leading)
                .deepInset()
                .accessibilityLabel("Recovery key. Use Copy or Export recovery kit to copy it.")
                .accessibilityValue("Hidden")

            HStack {
                Button(action: copyRecoveryKey) {
                    Label("Copy", systemImage: "doc.on.doc")
                }
                Button(action: exportRecoveryKit) {
                    Label("Export recovery kit...", systemImage: "square.and.arrow.down")
                }
                Spacer()
                Button("Done") { dismiss() }
                if installsKey {
                    Button(currentFingerprint == nil ? "I saved this key" : "Replace and keep the old key") {
                        onInstall()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(!hasSavedKey)
                }
            }
        }
        .padding(Tokens.Space.xl)
        .frame(minWidth: 320, idealWidth: 620, maxWidth: 720)
    }

    private func exportRecoveryKit() {
        let panel = NSSavePanel()
        panel.title = "Export Vibe Vault recovery kit"
        panel.nameFieldStringValue = "VibeVault-Recovery-Kit.txt"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            let body = try RecoveryKitDocument.contents(
                canonicalKey: recoveryKey,
                createdAt: createdAt
            )
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
        hasSavedKey = true
        let changeCount = pasteboard.changeCount
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 60_000_000_000)
            guard pasteboard.changeCount == changeCount,
                  pasteboard.string(forType: .string) == recoveryKey else { return }
            pasteboard.clearContents()
        }
    }
}
