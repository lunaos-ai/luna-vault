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
    @State var recoverySheetFingerprint = ""
    @State var recoverySheetCreatedAt = Date()
    @State var recoverySheetInstallsKey = false
    @State var recoverySheetCurrentFingerprint: String?
    @State var showExportBackupSheet = false
    @State var showImportBackupSheet = false
    @State var showRecoverySheet = false
    @State var confirmStopActive = false
    @State var confirmReplaceActive = false
    @State var confirmRemoveRetained = false
    @State var pendingEnteredActiveKey = ""
    @State var pendingPromoteIdentifier: String?
    @State var pendingRemoveIdentifier: String?
    @State var removeRetainedMessageText = ""
    @State var bundleInfo: CloudSyncBundleInfo?
    @State var recoveryErrorText: String?

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

    var canPreviewRecovery: Bool {
        !isWorking
            && status?.bundleExists == true
            && (canUseRecoveryKey || !env.cachedRecoveryKeys.isEmpty)
    }

    var canImportSelectedWithRecovery: Bool {
        !isWorking
            && selectedBackupURL != nil
            && preview != nil
            && selectedUnlockMethod == .recoveryKey
    }

    var canRunManagedBackup: Bool {
        !isWorking
            && (status?.iCloudAvailable ?? false)
            && (canEncrypt || env.automaticBackupCredentialAvailable())
    }

    var canChooseRecoveryBackup: Bool {
        !isWorking && (canUseRecoveryKey || !env.cachedRecoveryKeys.isEmpty)
    }

    var body: some View {
        applyCloudSyncChrome(syncSection)
    }

    private var syncSection: some View {
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
            recoverySection
        } header: {
            Text("Encrypted sync and backups")
        } footer: {
            Text("Sync to iCloud shares one encrypted bundle between Macs. Export backup saves a portable file anywhere. Enable schedule stores the passphrase in Keychain for automatic iCloud snapshots while the app stays open.")
        }
    }

    private var recoverySection: some View {
        CloudSyncRecoveryKeySection(
            recoveryRestoreKey: $recoveryRestoreKey,
            canUseRecoveryKey: canUseRecoveryKey,
            canPreviewRecovery: canPreviewRecovery,
            canImportSelectedWithRecovery: canImportSelectedWithRecovery,
            status: status,
            bundleInfo: bundleInfo,
            recoveryErrorText: recoveryErrorText,
            onShow: showRecoveryKey,
            onCreate: createRecoveryKey,
            onStopActive: { confirmStopActive = true },
            onMakeActive: {
                pendingPromoteIdentifier = $0
                pendingEnteredActiveKey = ""
                if env.cachedHasBackupRecoveryKey {
                    confirmReplaceActive = true
                } else {
                    applyPendingActiveReplacement()
                }
            },
            onRemoveRetained: {
                pendingRemoveIdentifier = $0
                removeRetainedMessageText = removeRetainedMessage
                confirmRemoveRetained = true
            },
            onPreviewICloud: { previewRecoveryBackup(at: CloudSync.defaultICloudURL()) },
            onChooseBackup: chooseRecoveryImportURL,
            onImportSelected: importSelectedRecoveryBackup,
            onKeepEntered: keepEnteredRecoveryKey,
            onMakeEnteredActive: confirmMakeEnteredActive
        )
    }
}
