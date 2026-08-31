import AppKit
import SwiftUI
import UniformTypeIdentifiers
import VaultCore

extension CloudSyncSettingsSection {
    func refreshStatus() {
        status = env.cloudSyncStatus()
        backupHistory = env.managedCloudBackups()
        env.refreshRecoveryKeyCache()
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
