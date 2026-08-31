import AppKit
import SwiftUI
import UniformTypeIdentifiers
import VaultCore

extension CloudSyncSettingsSection {
    func previewRecoveryBackup(at url: URL) {
        guard canChooseRecoveryBackup else { return }
        selectedBackupURL = url
        selectedUnlockMethod = .recoveryKey
        do {
            bundleInfo = try env.inspectCloudSyncBundle(at: url)
        } catch {
            bundleInfo = nil
            recoveryErrorText = "\(error)"
            preview = nil
            env.showToast("Recovery preview failed", feedback: .caution)
            return
        }
        do {
            let trimmed = recoveryRestoreKey.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                guard canUseRecoveryKey else {
                    preview = nil
                    recoveryErrorText = CloudSyncError.invalidRecoveryKey.description
                    env.showToast("Recovery preview failed", feedback: .caution)
                    return
                }
                preview = try env.previewCloudSyncBundle(at: url, recoveryKey: recoveryRestoreKey)
            } else {
                preview = try env.previewCloudSyncBundleUsingKeyring(at: url)
            }
            recoveryErrorText = nil
            env.showToast("Recovery preview ready", feedback: .tick)
        } catch {
            preview = nil
            recoveryErrorText = "\(error)"
            env.showToast("Recovery preview failed", feedback: .caution)
        }
    }

    func chooseRecoveryImportURL() {
        guard canChooseRecoveryBackup else { return }
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
        let imported: Bool
        if canUseRecoveryKey {
            imported = await env.pullCloudSync(
                from: selectedBackupURL,
                recoveryKey: recoveryRestoreKey,
                policy: importPolicy,
                sourceName: "recovery backup"
            )
        } else {
            imported = await env.pullCloudSyncUsingKeyring(
                from: selectedBackupURL,
                policy: importPolicy,
                sourceName: "recovery backup"
            )
        }
        if imported { recoveryRestoreKey = "" }
    }

    func createRecoveryKey() {
        do {
            let key = try env.generateBackupRecoveryKey()
            recoverySheetKey = key
            recoverySheetFingerprint = try CloudRecoveryKey.fingerprint(forKey: key)
            recoverySheetCreatedAt = Date()
            recoverySheetInstallsKey = true
            recoverySheetCurrentFingerprint = env.cachedRecoveryKeys.first(where: \.isActive)?.fingerprint
            showRecoverySheet = true
        } catch {
            recoveryErrorText = "\(error)"
            env.showToast("Could not create recovery key", feedback: .caution)
        }
    }

    func showRecoveryKey(identifier: String) async {
        do {
            recoverySheetKey = try await env.revealRecoveryKey(identifier: identifier)
            let summary = env.cachedRecoveryKeys.first { $0.identifier == identifier }
            recoverySheetFingerprint = summary?.fingerprint
                ?? (try? CloudRecoveryKey.fingerprint(forKey: recoverySheetKey))
                ?? ""
            recoverySheetCreatedAt = summary?.createdAt ?? Date()
            recoverySheetInstallsKey = false
            recoverySheetCurrentFingerprint = nil
            showRecoverySheet = true
        } catch {
            recoveryErrorText = "\(error)"
            env.showToast("Could not unlock recovery key", feedback: .caution)
        }
    }

    func keepEnteredRecoveryKey() {
        do {
            try env.keepRecoveryKeyForRestores(recoveryRestoreKey)
        } catch {
            recoveryErrorText = "\(error)"
            env.showToast("Could not keep recovery key", feedback: .caution)
        }
    }

    func confirmMakeEnteredActive() {
        pendingEnteredActiveKey = recoveryRestoreKey
        pendingPromoteIdentifier = nil
        if env.cachedHasBackupRecoveryKey {
            confirmReplaceActive = true
        } else {
            applyPendingActiveReplacement()
        }
    }

    func applyPendingActiveReplacement() {
        do {
            if let identifier = pendingPromoteIdentifier,
               let record = env.loadedRecoveryKeyring().record(identifier: identifier) {
                try env.makeRecoveryKeyActive(record.canonicalKey, imported: record.importedAt != nil)
            } else if !pendingEnteredActiveKey.isEmpty {
                try env.makeRecoveryKeyActive(pendingEnteredActiveKey, imported: true)
            }
        } catch {
            recoveryErrorText = "\(error)"
            env.showToast("Could not change the active recovery key", feedback: .caution)
        }
        pendingPromoteIdentifier = nil
        pendingEnteredActiveKey = ""
    }

    func removePendingRetainedKey() {
        guard let identifier = pendingRemoveIdentifier else { return }
        do {
            try env.removeRetainedRecoveryKey(identifier: identifier)
        } catch {
            recoveryErrorText = "\(error)"
            env.showToast("Could not remove recovery key", feedback: .caution)
        }
        pendingRemoveIdentifier = nil
    }

    func installGeneratedRecoveryKey() {
        do {
            try env.saveBackupRecoveryKey(recoverySheetKey)
            showRecoverySheet = false
        } catch {
            recoveryErrorText = "\(error)"
        }
    }
}
