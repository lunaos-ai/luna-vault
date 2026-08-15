import AppKit
import SwiftUI
import UniformTypeIdentifiers
import VaultCore

struct ExportBackupSheet: View {
    @Environment(\.dismiss) private var dismiss
    let recoveryProtectionEnabled: Bool
    let onExport: (URL, String) async -> Bool
    @State private var passphrase = ""
    @State private var confirmation = ""
    @State private var isExporting = false
    @State private var exportFailed = false

    private var hasValidPassphraseLength: Bool {
        passphrase.count >= 12
    }

    private var passphrasesMatch: Bool {
        !confirmation.isEmpty && passphrase == confirmation
    }

    private var canExport: Bool {
        hasValidPassphraseLength && passphrasesMatch && !isExporting
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.lg) {
            Label("Export encrypted backup", systemImage: "externaldrive.badge.plus")
                .font(.title2.weight(.semibold))

            Text("Create a portable .vvsync file for another Mac or for offline recovery. Choose a new passphrase for this backup file.")
                .foregroundStyle(Tokens.Text.secondary)

            SecureField("Backup passphrase", text: $passphrase)
                .textContentType(.newPassword)
            SecureField("Confirm backup passphrase", text: $confirmation)
                .textContentType(.newPassword)

            HStack(spacing: Tokens.Space.lg) {
                requirement("12+ characters", satisfied: hasValidPassphraseLength)
                requirement("Passphrases match", satisfied: passphrasesMatch)
            }
            .font(.caption)

            Label(
                recoveryProtectionEnabled
                    ? "Your recovery key will also protect this backup."
                    : "This passphrase is the only way to unlock the exported backup.",
                systemImage: recoveryProtectionEnabled ? "key.fill" : "exclamationmark.shield"
            )
            .font(.callout)
            .foregroundStyle(Tokens.Text.secondary)

            if exportFailed {
                Label("The backup could not be exported. Review the app error and try again.", systemImage: "exclamationmark.triangle.fill")
                    .font(.callout)
                    .foregroundStyle(Tokens.Status.danger)
            }

            Divider()

            HStack {
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                    .disabled(isExporting)

                Spacer()

                Button {
                    chooseDestinationAndExport()
                } label: {
                    if isExporting {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Label("Choose destination and export", systemImage: "square.and.arrow.down")
                    }
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
                .disabled(!canExport)
            }
        }
        .padding(Tokens.Space.xl)
        .frame(width: 560)
        .onChange(of: passphrase) { _, _ in exportFailed = false }
        .onChange(of: confirmation) { _, _ in exportFailed = false }
    }

    private func requirement(_ label: String, satisfied: Bool) -> some View {
        Label(label, systemImage: satisfied ? "checkmark.circle.fill" : "circle")
            .foregroundStyle(satisfied ? Tokens.Status.success : Tokens.Text.secondary)
    }

    private func chooseDestinationAndExport() {
        guard canExport else { return }
        let panel = NSSavePanel()
        panel.nameFieldStringValue = CloudSync.fileName
        panel.title = "Export encrypted Vibe Vault backup"
        panel.canCreateDirectories = true
        if let type = UTType(filenameExtension: "vvsync") {
            panel.allowedContentTypes = [type]
        }
        guard panel.runModal() == .OK, let url = panel.url else { return }

        let exportPassphrase = passphrase
        isExporting = true
        exportFailed = false
        Task { @MainActor in
            let exported = await onExport(url, exportPassphrase)
            isExporting = false
            if exported {
                passphrase = ""
                confirmation = ""
                dismiss()
            } else {
                exportFailed = true
            }
        }
    }
}
