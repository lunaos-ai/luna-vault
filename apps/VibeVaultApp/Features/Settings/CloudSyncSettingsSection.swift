import AppKit
import SwiftUI
import UniformTypeIdentifiers
import VaultCore

struct CloudSyncSettingsSection: View {
    @EnvironmentObject var env: AppEnvironment
    @State private var passphrase = ""
    @State private var confirmation = ""
    @State private var overwrite = false
    @State private var isWorking = false
    @State private var status: AppCloudSyncStatus?
    @State private var preview: AppCloudSyncPreview?
    @State private var selectedBackupURL: URL?

    private var canPush: Bool {
        passphrase.count >= 12 && passphrase == confirmation && !isWorking
    }

    private var canPull: Bool {
        passphrase.count >= 12 && !isWorking && (status?.bundleExists ?? false)
    }

    private var canPreview: Bool {
        passphrase.count >= 12 && !isWorking
    }

    private var canImportSelected: Bool {
        canPreview && selectedBackupURL != nil && preview != nil
    }

    var body: some View {
        Section {
            if let status {
                LabeledContent("Local secrets", value: "\(status.localCount)")
                LabeledContent("iCloud bundle", value: status.bundleExists ? "Present" : "Missing")
                LabeledContent("Updated", value: status.modifiedText)
                LabeledContent("Size", value: status.sizeText)
            }

            SecureField("Sync passphrase", text: $passphrase)
            SecureField("Confirm passphrase", text: $confirmation)

            Toggle("Overwrite matching names on import", isOn: $overwrite)

            HStack {
                Button {
                    Task { await push() }
                } label: {
                    Label("Sync to iCloud", systemImage: "icloud.and.arrow.up")
                }
                .disabled(!canPush)

                Button {
                    Task { await pull() }
                } label: {
                    Label("Import from iCloud", systemImage: "icloud.and.arrow.down")
                }
                .disabled(!canPull)

                Button {
                    previewICloud()
                } label: {
                    Label("Preview iCloud", systemImage: "doc.text.magnifyingglass")
                }
                .disabled(!canPull)

                Button {
                    refreshStatus()
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
                .disabled(isWorking)
            }

            HStack {
                Button {
                    chooseExportURL()
                } label: {
                    Label("Export backup...", systemImage: "externaldrive.badge.plus")
                }
                .disabled(!canPush)

                Button {
                    chooseImportURL()
                } label: {
                    Label("Choose backup...", systemImage: "folder")
                }
                .disabled(!canPreview)

                Button {
                    Task { await importSelectedBackup() }
                } label: {
                    Label("Import selected", systemImage: "square.and.arrow.down")
                }
                .disabled(!canImportSelected)
            }

            if let preview {
                VStack(alignment: .leading, spacing: 8) {
                    LabeledContent("Selected bundle", value: preview.path)
                    LabeledContent("Source Mac", value: preview.sourceHost)
                    LabeledContent("Exported", value: preview.exportedAtText)
                    LabeledContent("Secrets", value: "\(preview.secretCount)")
                    LabeledContent("Size", value: preview.sizeText)
                }
                .font(.caption)
                .textSelection(.enabled)
            }

            if let status {
                Text(status.path)
                    .font(.caption)
                    .foregroundStyle(Tokens.Text.secondary)
                    .textSelection(.enabled)
            }
        } header: {
            Text("Cloud Sync")
        } footer: {
            Text("Encrypted iCloud Drive bundle and manual .vvsync backups. The passphrase is not saved.")
        }
        .onAppear { refreshStatus() }
        .onChange(of: passphrase) { _, _ in
            preview = nil
            selectedBackupURL = nil
        }
    }

    private func refreshStatus() {
        status = env.cloudSyncStatus()
    }

    private func push() async {
        guard canPush else { return }
        isWorking = true
        defer {
            isWorking = false
            refreshStatus()
        }
        if await env.pushCloudSync(passphrase: passphrase) {
            confirmation = ""
        }
    }

    private func pull() async {
        guard canPull else { return }
        isWorking = true
        defer {
            isWorking = false
            refreshStatus()
        }
        _ = await env.pullCloudSync(passphrase: passphrase, overwrite: overwrite)
    }

    private func previewICloud() {
        guard canPull else { return }
        previewBackup(at: CloudSync.defaultICloudURL())
    }

    private func chooseExportURL() {
        guard canPush else { return }
        let panel = NSSavePanel()
        panel.nameFieldStringValue = CloudSync.fileName
        panel.title = "Export encrypted Vibe Vault backup"
        panel.canCreateDirectories = true
        if let type = UTType(filenameExtension: "vvsync") {
            panel.allowedContentTypes = [type]
        }
        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            Task { await exportBackup(to: url) }
        }
    }

    private func chooseImportURL() {
        guard canPreview else { return }
        let panel = NSOpenPanel()
        panel.title = "Choose encrypted Vibe Vault backup"
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        if let type = UTType(filenameExtension: "vvsync") {
            panel.allowedContentTypes = [type]
        }
        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            previewBackup(at: url)
        }
    }

    private func previewBackup(at url: URL) {
        guard canPreview else { return }
        do {
            selectedBackupURL = url
            preview = try env.previewCloudSyncBundle(at: url, passphrase: passphrase)
            env.showToast("Backup preview ready", feedback: .tick)
        } catch {
            selectedBackupURL = nil
            preview = nil
            env.lastError = "\(error)"
            env.showToast("Backup preview failed", feedback: .caution)
        }
    }

    private func exportBackup(to url: URL) async {
        guard canPush else { return }
        isWorking = true
        let exported = await env.pushCloudSync(to: url, passphrase: passphrase, destinationName: "backup")
        isWorking = false
        refreshStatus()
        if exported {
            confirmation = ""
            previewBackup(at: url)
        }
    }

    private func importSelectedBackup() async {
        guard canImportSelected, let selectedBackupURL else { return }
        isWorking = true
        defer {
            isWorking = false
            refreshStatus()
        }
        _ = await env.pullCloudSync(
            from: selectedBackupURL,
            passphrase: passphrase,
            overwrite: overwrite,
            sourceName: "backup"
        )
    }
}
