import AppKit
import SwiftUI
import UniformTypeIdentifiers
import VaultCore

struct ImportBackupSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var env: AppEnvironment
    let onImport: (URL, String, AppCloudSyncImportPolicy) async -> Bool
    @State private var selectedURL: URL?
    @State private var passphrase = ""
    @State private var policy: AppCloudSyncImportPolicy
    @State private var preview: AppCloudSyncPreview?
    @State private var previewError: String?
    @State private var isImporting = false

    init(
        initialPolicy: AppCloudSyncImportPolicy,
        onImport: @escaping (URL, String, AppCloudSyncImportPolicy) async -> Bool
    ) {
        self.onImport = onImport
        _policy = State(initialValue: initialPolicy)
    }

    private var canPreview: Bool {
        selectedURL != nil && passphrase.count >= 12 && !isImporting
    }

    private var canImport: Bool {
        canPreview && preview != nil
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.lg) {
            Label("Import encrypted backup", systemImage: "square.and.arrow.down")
                .font(.title2.weight(.semibold))

            Text("Choose a portable .vvsync backup, unlock it with its passphrase, then review its contents before importing.")
                .foregroundStyle(Tokens.Text.secondary)

            HStack(spacing: Tokens.Space.md) {
                Label(
                    selectedURL?.lastPathComponent ?? "No backup selected",
                    systemImage: selectedURL == nil ? "doc.badge.plus" : "lock.doc"
                )
                .lineLimit(1)
                .truncationMode(.middle)

                Spacer()

                Button {
                    chooseBackup()
                } label: {
                    Label(selectedURL == nil ? "Choose backup..." : "Change...", systemImage: "folder")
                }
                .disabled(isImporting)
            }
            .padding(Tokens.Space.md)
            .deepInset()

            SecureField("Backup passphrase", text: $passphrase)
                .textContentType(.password)

            Label(
                "At least 12 characters",
                systemImage: passphrase.count >= 12 ? "checkmark.circle.fill" : "circle"
            )
            .font(.caption)
            .foregroundStyle(passphrase.count >= 12 ? Tokens.Status.success : Tokens.Text.secondary)

            Picker("Existing names", selection: $policy) {
                ForEach(AppCloudSyncImportPolicy.allCases) { option in
                    Text(option.label).tag(option)
                }
            }
            .pickerStyle(.segmented)
            .disabled(isImporting)

            HStack {
                Button {
                    previewBackup()
                } label: {
                    Label("Preview backup", systemImage: "doc.text.magnifyingglass")
                }
                .disabled(!canPreview)

                if preview != nil {
                    Label("Ready to import", systemImage: "checkmark.circle.fill")
                        .font(.callout)
                        .foregroundStyle(Tokens.Status.success)
                }
            }

            if let preview {
                VStack(alignment: .leading, spacing: Tokens.Space.sm) {
                    LabeledContent("Source Mac", value: preview.sourceHost)
                    LabeledContent("Exported", value: preview.exportedAtText)
                    LabeledContent("Secrets", value: "\(preview.secretCount)")
                    LabeledContent("Saved versions", value: "\(preview.revisionCount)")
                    LabeledContent("Size", value: preview.sizeText)
                    Divider()
                    LabeledContent("New locally", value: "\(preview.newCount)")
                    LabeledContent("Backup is newer", value: "\(preview.backupNewerCount)")
                    LabeledContent("Local is newer", value: "\(preview.localNewerCount)")
                }
                .font(.callout)
                .textSelection(.enabled)
            }

            if let previewError {
                Label(previewError, systemImage: "exclamationmark.triangle.fill")
                    .font(.callout)
                    .foregroundStyle(Tokens.Status.danger)
            }

            Divider()

            HStack {
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                    .disabled(isImporting)

                Spacer()

                Button {
                    importBackup()
                } label: {
                    if isImporting {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Label("Import backup", systemImage: "square.and.arrow.down")
                    }
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
                .disabled(!canImport)
            }
        }
        .padding(Tokens.Space.xl)
        .frame(width: 580)
        .onChange(of: passphrase) { _, _ in resetPreview() }
        .onChange(of: policy) { _, _ in resetPreview() }
    }

    private func chooseBackup() {
        let panel = NSOpenPanel()
        panel.title = "Choose encrypted Vibe Vault backup"
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        if let type = UTType(filenameExtension: "vvsync") {
            panel.allowedContentTypes = [type]
        }
        guard panel.runModal() == .OK, let url = panel.url else { return }
        selectedURL = url
        resetPreview()
    }

    private func previewBackup() {
        guard canPreview, let selectedURL else { return }
        do {
            preview = try env.previewCloudSyncBundle(at: selectedURL, passphrase: passphrase)
            previewError = nil
            env.showToast("Backup preview ready", feedback: .tick)
        } catch {
            preview = nil
            previewError = "Could not unlock this backup. Check the file and passphrase."
            env.lastError = "\(error)"
            env.showToast("Backup preview failed", feedback: .caution)
        }
    }

    private func importBackup() {
        guard canImport, let selectedURL else { return }
        let importPassphrase = passphrase
        let importPolicy = policy
        isImporting = true
        previewError = nil
        Task { @MainActor in
            let imported = await onImport(selectedURL, importPassphrase, importPolicy)
            isImporting = false
            if imported {
                passphrase = ""
                dismiss()
            } else {
                previewError = "The backup could not be imported. Review the app error and try again."
            }
        }
    }

    private func resetPreview() {
        preview = nil
        previewError = nil
    }
}
