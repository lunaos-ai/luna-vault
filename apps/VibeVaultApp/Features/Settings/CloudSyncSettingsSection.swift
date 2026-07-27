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
    @State private var selectedUnlockMethod: BackupUnlockMethod?
    @State private var backupHistory: [CloudBackupFile] = []
    @State private var recoveryRestoreKey = ""
    @State private var recoverySheetKey = ""
    @State private var recoverySheetInstallsKey = false
    @State private var showExportBackupSheet = false
    @State private var showImportBackupSheet = false
    @State private var showRecoverySheet = false
    @State private var confirmRemoveRecoveryKey = false

    private var canEncrypt: Bool {
        passphrase.count >= 12 && passphrase == confirmation && !isWorking
    }

    private var hasValidPassphraseLength: Bool {
        passphrase.count >= 12
    }

    private var passphrasesMatch: Bool {
        !confirmation.isEmpty && passphrase == confirmation
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

    private var canUseRecoveryKey: Bool {
        (try? CloudRecoveryKey.canonicalize(recoveryRestoreKey)) != nil && !isWorking
    }

    private var canImportSelectedWithRecovery: Bool {
        canUseRecoveryKey
            && selectedBackupURL != nil
            && preview != nil
            && selectedUnlockMethod == .recoveryKey
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
            HStack(spacing: Tokens.Space.lg) {
                passphraseRequirement("12+ characters", satisfied: hasValidPassphraseLength)
                passphraseRequirement("Passphrases match", satisfied: passphrasesMatch)
            }
            .font(.caption)

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
                    showExportBackupSheet = true
                } label: {
                    Label("Export encrypted backup...", systemImage: "externaldrive.badge.plus")
                }
                .disabled(isWorking)

                Button {
                    showImportBackupSheet = true
                } label: {
                    Label("Import encrypted backup...", systemImage: "square.and.arrow.down")
                }
                .disabled(isWorking)
            }

            LabeledContent(
                "Recovery protection",
                value: env.cachedHasBackupRecoveryKey ? "Enabled for new backups" : "Not configured"
            )

            HStack {
                if env.cachedHasBackupRecoveryKey {
                    Button {
                        Task { await showInstalledRecoveryKey() }
                    } label: {
                        Label("Show or export key", systemImage: "key.viewfinder")
                    }

                    Button {
                        createRecoveryKey()
                    } label: {
                        Label("Replace key", systemImage: "arrow.triangle.2.circlepath")
                    }

                    Button(role: .destructive) {
                        confirmRemoveRecoveryKey = true
                    } label: {
                        Label("Remove", systemImage: "trash")
                    }
                } else {
                    Button {
                        createRecoveryKey()
                    } label: {
                        Label("Create recovery key", systemImage: "key.fill")
                    }
                    .buttonStyle(.borderedProminent)
                }
            }

            DisclosureGroup("Restore with recovery key") {
                SecureField("VV-RK1 recovery key", text: $recoveryRestoreKey)
                    .font(.system(.body, design: .monospaced))

                HStack {
                    Button {
                        previewRecoveryBackup(at: CloudSync.defaultICloudURL())
                    } label: {
                        Label("Preview iCloud", systemImage: "doc.text.magnifyingglass")
                    }
                    .disabled(!canUseRecoveryKey || status?.bundleExists != true)

                    Button {
                        chooseRecoveryImportURL()
                    } label: {
                        Label("Choose backup...", systemImage: "folder")
                    }
                    .disabled(!canUseRecoveryKey)

                    Button {
                        Task { await importSelectedRecoveryBackup() }
                    } label: {
                        Label("Import selected", systemImage: "square.and.arrow.down")
                    }
                    .disabled(!canImportSelectedWithRecovery)
                }

                Button {
                    saveEnteredRecoveryKey()
                } label: {
                    Label("Use this key for future backups", systemImage: "key.icloud")
                }
                .disabled(!canUseRecoveryKey)
            }

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
                    LabeledContent("Saved versions", value: "\(preview.revisionCount)")
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
            Text("Manual passphrases are not saved. Scheduled-backup credentials and an enabled recovery key stay in this Mac's Keychain. Backups run while the app is open and the vault is unlocked.")
        }
        .onAppear { refreshStatus() }
        .onChange(of: passphrase) { _, _ in
            preview = nil
            selectedBackupURL = nil
            selectedUnlockMethod = nil
        }
        .onChange(of: recoveryRestoreKey) { _, _ in
            preview = nil
            selectedBackupURL = nil
            selectedUnlockMethod = nil
        }
        .sheet(isPresented: $showExportBackupSheet) {
            ExportBackupSheet(
                recoveryProtectionEnabled: env.cachedHasBackupRecoveryKey,
                onExport: { url, exportPassphrase in
                    await exportBackup(to: url, passphrase: exportPassphrase)
                }
            )
        }
        .sheet(isPresented: $showImportBackupSheet) {
            ImportBackupSheet(
                initialPolicy: importPolicy,
                onImport: { url, importPassphrase, policy in
                    importPolicy = policy
                    return await importBackup(
                        from: url,
                        passphrase: importPassphrase,
                        policy: policy
                    )
                }
            )
            .environmentObject(env)
        }
        .sheet(isPresented: $showRecoverySheet) {
            RecoveryKeySheet(
                recoveryKey: recoverySheetKey,
                installsKey: recoverySheetInstallsKey,
                onInstall: {
                    do {
                        try env.saveBackupRecoveryKey(recoverySheetKey)
                        showRecoverySheet = false
                    } catch {
                        env.lastError = "\(error)"
                    }
                }
            )
        }
        .onChange(of: showRecoverySheet) { _, isPresented in
            if !isPresented { recoverySheetKey = "" }
        }
        .confirmationDialog(
            "Remove recovery protection from future backups?",
            isPresented: $confirmRemoveRecoveryKey,
            titleVisibility: .visible
        ) {
            Button("Remove", role: .destructive) { env.removeBackupRecoveryKey() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Existing protected backups still require this recovery key. New backups will use only the sync passphrase.")
        }
    }

    private func passphraseRequirement(_ label: String, satisfied: Bool) -> some View {
        Label(label, systemImage: satisfied ? "checkmark.circle.fill" : "circle")
            .foregroundStyle(satisfied ? Tokens.Status.success : Tokens.Text.secondary)
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

    private func previewBackup(at url: URL) {
        guard canPreview else { return }
        do {
            selectedBackupURL = url
            selectedUnlockMethod = .passphrase
            preview = try env.previewCloudSyncBundle(at: url, passphrase: passphrase)
            env.showToast("Backup preview ready", feedback: .tick)
        } catch {
            selectedBackupURL = nil
            selectedUnlockMethod = nil
            preview = nil
            env.lastError = "\(error)"
            env.showToast("Backup preview failed", feedback: .caution)
        }
    }

    private func previewRecoveryBackup(at url: URL) {
        guard canUseRecoveryKey else { return }
        do {
            selectedBackupURL = url
            selectedUnlockMethod = .recoveryKey
            preview = try env.previewCloudSyncBundle(at: url, recoveryKey: recoveryRestoreKey)
            env.showToast("Recovery preview ready", feedback: .tick)
        } catch {
            selectedBackupURL = nil
            selectedUnlockMethod = nil
            preview = nil
            env.lastError = "\(error)"
            env.showToast("Recovery preview failed", feedback: .caution)
        }
    }

    private func chooseRecoveryImportURL() {
        guard canUseRecoveryKey else { return }
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
            previewRecoveryBackup(at: url)
        }
    }

    private func importSelectedRecoveryBackup() async {
        guard canImportSelectedWithRecovery, let selectedBackupURL else { return }
        isWorking = true
        defer {
            isWorking = false
            refreshStatus()
        }
        let imported = await env.pullCloudSync(
            from: selectedBackupURL,
            recoveryKey: recoveryRestoreKey,
            policy: importPolicy,
            sourceName: "recovery backup"
        )
        if imported { recoveryRestoreKey = "" }
    }

    private func createRecoveryKey() {
        do {
            recoverySheetKey = try env.generateBackupRecoveryKey()
            recoverySheetInstallsKey = true
            showRecoverySheet = true
        } catch {
            env.lastError = "\(error)"
            env.showToast("Could not create recovery key", feedback: .caution)
        }
    }

    private func saveEnteredRecoveryKey() {
        do {
            try env.saveBackupRecoveryKey(recoveryRestoreKey)
        } catch {
            env.lastError = "\(error)"
            env.showToast("Could not save recovery key", feedback: .caution)
        }
    }

    private func showInstalledRecoveryKey() async {
        do {
            recoverySheetKey = try await env.revealBackupRecoveryKey()
            recoverySheetInstallsKey = false
            showRecoverySheet = true
        } catch {
            env.lastError = "\(error)"
            env.showToast("Could not unlock recovery key", feedback: .caution)
        }
    }

    private func exportBackup(to url: URL, passphrase exportPassphrase: String) async -> Bool {
        guard exportPassphrase.count >= 12, !isWorking else { return false }
        isWorking = true
        defer {
            isWorking = false
            refreshStatus()
        }
        return await env.pushCloudSync(
            to: url,
            passphrase: exportPassphrase,
            destinationName: "backup"
        )
    }

    private func importBackup(
        from url: URL,
        passphrase importPassphrase: String,
        policy: AppCloudSyncImportPolicy
    ) async -> Bool {
        guard importPassphrase.count >= 12, !isWorking else { return false }
        isWorking = true
        defer {
            isWorking = false
            refreshStatus()
        }
        return await env.pullCloudSync(
            from: url,
            passphrase: importPassphrase,
            policy: policy,
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

private enum BackupUnlockMethod {
    case passphrase
    case recoveryKey
}

private struct ImportBackupSheet: View {
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

private struct ExportBackupSheet: View {
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

private struct RecoveryKeySheet: View {
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
