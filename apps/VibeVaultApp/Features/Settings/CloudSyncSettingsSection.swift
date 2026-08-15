import AppKit
import SwiftUI
import UniformTypeIdentifiers
import VaultCore

struct CloudSyncSettingsSection: View {
    @EnvironmentObject var env: AppEnvironment
    var onStatusChange: () -> Void = {}
    @State var passphrase = ""
    @State var confirmation = ""
    @State var importPolicy: AppCloudSyncImportPolicy = .keepLocal
    @State var isWorking = false
    @State var status: AppCloudSyncStatus?
    @State var preview: AppCloudSyncPreview?
    @State var selectedBackupURL: URL?
    @State var selectedUnlockMethod: BackupUnlockMethod?
    @State var backupHistory: [CloudBackupFile] = []
    @State var recoveryRestoreKey = ""
    @State var recoverySheetKey = ""
    @State var recoverySheetInstallsKey = false
    @State var showExportBackupSheet = false
    @State var showImportBackupSheet = false
    @State var showRecoverySheet = false
    @State var confirmRemoveRecoveryKey = false

    var canEncrypt: Bool {
        passphrase.count >= 12 && passphrase == confirmation && !isWorking
    }

    var canSyncToICloud: Bool {
        canEncrypt && (status?.iCloudAvailable ?? false)
    }

    var canPull: Bool {
        passphrase.count >= 12 && !isWorking && (status?.bundleExists ?? false)
    }

    var canPreview: Bool {
        passphrase.count >= 12 && !isWorking
    }

    var canUseRecoveryKey: Bool {
        (try? CloudRecoveryKey.canonicalize(recoveryRestoreKey)) != nil && !isWorking
    }

    var canImportSelectedWithRecovery: Bool {
        canUseRecoveryKey
            && selectedBackupURL != nil
            && preview != nil
            && selectedUnlockMethod == .recoveryKey
    }

    var canRunManagedBackup: Bool {
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

            CloudSyncPassphraseSection(
                passphrase: $passphrase,
                confirmation: $confirmation,
                importPolicy: $importPolicy
            )

            CloudSyncActionButtons(
                canSyncToICloud: canSyncToICloud,
                canPull: canPull,
                isWorking: isWorking,
                onPush: push,
                onPull: pull,
                onPreview: previewICloud,
                onRefresh: refreshStatus
            )

            CloudSyncBackupSection(
                showExportBackupSheet: $showExportBackupSheet,
                showImportBackupSheet: $showImportBackupSheet,
                isWorking: isWorking,
                canSyncToICloud: canSyncToICloud,
                canRunManagedBackup: canRunManagedBackup,
                canPreview: canPreview,
                status: status,
                backupHistory: backupHistory,
                preview: preview,
                onPreviewBackup: { previewBackup(at: $0) },
                onBackupNow: createManagedBackup,
                onEnable: enableAutomaticBackups,
                onDisable: {
                    env.disableAutomaticCloudBackups()
                    refreshStatus()
                },
                onPrune: {
                    env.pruneManagedCloudBackups()
                    refreshStatus()
                }
            )

            CloudSyncRecoveryKeySection(
                recoveryRestoreKey: $recoveryRestoreKey,
                canUseRecoveryKey: canUseRecoveryKey,
                canImportSelectedWithRecovery: canImportSelectedWithRecovery,
                status: status,
                selectedBackupURL: selectedBackupURL,
                preview: preview,
                onShowInstalled: showInstalledRecoveryKey,
                onCreate: createRecoveryKey,
                onConfirmRemove: { confirmRemoveRecoveryKey = true },
                onPreviewICloud: { previewRecoveryBackup(at: CloudSync.defaultICloudURL()) },
                onChooseBackup: chooseRecoveryImportURL,
                onImportSelected: importSelectedRecoveryBackup,
                onSaveEnteredKey: saveEnteredRecoveryKey
            )
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
}
