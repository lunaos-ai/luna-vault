import AppKit
import SwiftUI
import UniformTypeIdentifiers
import VaultCore

extension CloudSyncSettingsSection {
    func refreshStatus() {
        status = env.cloudSyncStatus()
        backupHistory = env.managedCloudBackups()
        onStatusChange()
    }
    func push() async {
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

    func pull() async {
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

    func previewICloud() {
        guard canPull else { return }
        previewBackup(at: CloudSync.defaultICloudURL())
    }

    func previewBackup(at url: URL) {
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

    func previewRecoveryBackup(at url: URL) {
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

    func chooseRecoveryImportURL() {
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

    func importSelectedRecoveryBackup() async {
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

    func createRecoveryKey() {
        do {
            recoverySheetKey = try env.generateBackupRecoveryKey()
            recoverySheetInstallsKey = true
            showRecoverySheet = true
        } catch {
            env.lastError = "\(error)"
            env.showToast("Could not create recovery key", feedback: .caution)
        }
    }

    func saveEnteredRecoveryKey() {
        do {
            try env.saveBackupRecoveryKey(recoveryRestoreKey)
        } catch {
            env.lastError = "\(error)"
            env.showToast("Could not save recovery key", feedback: .caution)
        }
    }

    func showInstalledRecoveryKey() async {
        do {
            recoverySheetKey = try await env.revealBackupRecoveryKey()
            recoverySheetInstallsKey = false
            showRecoverySheet = true
        } catch {
            env.lastError = "\(error)"
            env.showToast("Could not unlock recovery key", feedback: .caution)
        }
    }

    func exportBackup(to url: URL, passphrase exportPassphrase: String) async -> Bool {
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

    func importBackup(
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

    func enableAutomaticBackups() {
        guard canSyncToICloud else { return }
        if env.enableAutomaticCloudBackups(passphrase: passphrase) {
            confirmation = ""
            refreshStatus()
        }
    }

    func createManagedBackup() async {
        guard canRunManagedBackup else { return }
        let typedPassphrase = canEncrypt ? passphrase : nil
        isWorking = true
        _ = await env.runManagedCloudBackupNow(passphrase: typedPassphrase)
        isWorking = false
        confirmation = ""
        refreshStatus()
    }
}

enum BackupUnlockMethod {
    case passphrase
    case recoveryKey
}
