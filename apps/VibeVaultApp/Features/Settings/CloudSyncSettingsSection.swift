import AppKit
import SwiftUI
import UniformTypeIdentifiers
import VaultCore

struct CloudSyncSettingsSection: View {
    @EnvironmentObject var env: AppEnvironment
    var onStatusChange: () -> Void = {}
    @State private var passphrase = ""
    @State private var confirmation = ""
    @State private var importPolicy: AppCloudSyncImportPolicy = .keepLocal
    @State private var isWorking = false
    @State private var status: AppCloudSyncStatus?
    @State private var preview: AppCloudSyncPreview?
    @State private var selectedBackupURL: URL?
    @State private var backupHistory: [CloudBackupFile] = []

    private var canEncrypt: Bool {
        passphrase.count >= 12 && passphrase == confirmation && !isWorking
    }

    private var canSyncToICloud: Bool {
        canEncrypt && (status?.iCloudAvailable ?? false)
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

    private var canRunManagedBackup: Bool {
        !isWorking
            && (status?.iCloudAvailable ?? false)
            && (canEncrypt || env.automaticBackupCredentialAvailable())
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

            Picker("Existing names on import", selection: $importPolicy) {
                ForEach(AppCloudSyncImportPolicy.allCases) { policy in
                    Text(policy.label).tag(policy)
                }
            }
            .pickerStyle(.segmented)

            HStack {
                Button {
                    Task { await push() }
                } label: {
                    Label("Sync to iCloud", systemImage: "icloud.and.arrow.up")
                }
                .buttonStyle(.borderedProminent)
                .disabled(!canSyncToICloud)

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
                .disabled(!canEncrypt)

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

            Divider()

            LabeledContent(
                "Automatic backups",
                value: automaticBackupStatus
            )
            Picker("Frequency", selection: $env.backupIntervalHours) {
                Text("Every hour").tag(1)
                Text("Every 6 hours").tag(6)
                Text("Every 12 hours").tag(12)
                Text("Daily").tag(24)
                Text("Weekly").tag(168)
            }
            .disabled(!env.automaticBackupsEnabled)

            Stepper(
                "Keep \(env.backupRetentionCount) backup\(env.backupRetentionCount == 1 ? "" : "s")",
                value: $env.backupRetentionCount,
                in: 1...100
            )

            LabeledContent(
                "Last managed backup",
                value: env.lastManagedBackupAt?.formatted(date: .abbreviated, time: .shortened) ?? "Never"
            )

            HStack {
                if env.automaticBackupsEnabled {
                    Button(role: .destructive) {
                        env.disableAutomaticCloudBackups()
                        refreshStatus()
                    } label: {
                        Label("Disable schedule", systemImage: "calendar.badge.minus")
                    }
                } else {
                    Button {
                        enableAutomaticBackups()
                    } label: {
                        Label("Enable schedule", systemImage: "calendar.badge.plus")
                    }
                    .disabled(!canSyncToICloud)
                }

                Button {
                    Task { await createManagedBackup() }
                } label: {
                    Label("Back up now", systemImage: "clock.arrow.circlepath")
                }
                .disabled(!canRunManagedBackup)

                Button {
                    env.pruneManagedCloudBackups()
                    refreshStatus()
                } label: {
                    Label("Apply retention", systemImage: "trash.slash")
                }
                .disabled(isWorking || backupHistory.isEmpty)
            }

            if !backupHistory.isEmpty {
                DisclosureGroup("Backup history (\(backupHistory.count))") {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(backupHistory.prefix(10)) { backup in
                            Button {
                                previewBackup(at: backup.url)
                            } label: {
                                HStack {
                                    Image(systemName: "lock.doc")
                                    Text(backup.createdAt.formatted(date: .abbreviated, time: .shortened))
                                    Spacer()
                                    Text(ByteCountFormatter.string(fromByteCount: backup.size, countStyle: .file))
                                        .foregroundStyle(Tokens.Text.secondary)
                                }
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .disabled(!canPreview)
                        }
                    }
                    .padding(.top, 4)
                }
            }

            if let preview {
                VStack(alignment: .leading, spacing: 8) {
                    LabeledContent("Selected bundle", value: preview.path)
                    LabeledContent("Source Mac", value: preview.sourceHost)
                    LabeledContent("Exported", value: preview.exportedAtText)
                    LabeledContent("Secrets", value: "\(preview.secretCount)")
                    LabeledContent("Size", value: preview.sizeText)
                    LabeledContent("New locally", value: "\(preview.newCount)")
                    LabeledContent("Backup is newer", value: "\(preview.backupNewerCount)")
                    LabeledContent("Local is newer", value: "\(preview.localNewerCount)")
                    LabeledContent("Same timestamp", value: "\(preview.sameTimestampCount)")
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
            Text("Encrypted sync and backups")
        } footer: {
            Text("Manual passphrases are not saved. Enabling scheduled backups stores the passphrase in this Mac's Keychain and runs while the app is open and the vault is unlocked.")
        }
        .onAppear { refreshStatus() }
        .onChange(of: passphrase) { _, _ in
            preview = nil
            selectedBackupURL = nil
        }
    }

    private func refreshStatus() {
        status = env.cloudSyncStatus()
        backupHistory = env.managedCloudBackups()
        onStatusChange()
    }

    private var automaticBackupStatus: String {
        guard env.automaticBackupsEnabled else { return "Off" }
        return env.automaticBackupCredentialAvailable() ? "Enabled" : "Needs passphrase"
    }

    private func push() async {
        guard canSyncToICloud else { return }
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
        _ = await env.pullCloudSync(
            from: CloudSync.defaultICloudURL(),
            passphrase: passphrase,
            policy: importPolicy,
            sourceName: "iCloud"
        )
    }

    private func previewICloud() {
        guard canPull else { return }
        previewBackup(at: CloudSync.defaultICloudURL())
    }

    private func chooseExportURL() {
        guard canEncrypt else { return }
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
        guard canEncrypt else { return }
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
            policy: importPolicy,
            sourceName: "backup"
        )
    }

    private func enableAutomaticBackups() {
        guard canSyncToICloud else { return }
        if env.enableAutomaticCloudBackups(passphrase: passphrase) {
            confirmation = ""
            refreshStatus()
        }
    }

    private func createManagedBackup() async {
        guard canRunManagedBackup else { return }
        let typedPassphrase = canEncrypt ? passphrase : nil
        isWorking = true
        _ = await env.runManagedCloudBackupNow(passphrase: typedPassphrase)
        isWorking = false
        confirmation = ""
        refreshStatus()
    }
}
