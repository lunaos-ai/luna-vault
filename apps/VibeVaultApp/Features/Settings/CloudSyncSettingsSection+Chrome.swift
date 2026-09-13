import SwiftUI
import VaultCore

extension CloudSyncSettingsSection {
    func applyCloudSyncChrome<Content: View>(_ content: Content) -> some View {
        content
            .onAppear { refreshStatus() }
            .onChange(of: passphrase) { _, _ in
                preview = nil
                selectedBackupURL = nil
                selectedUnlockMethod = nil
                bundleInfo = nil
                recoveryErrorText = nil
            }
            .onChange(of: recoveryRestoreKey) { _, _ in
                preview = nil
                recoveryErrorText = nil
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
                    fingerprint: recoverySheetFingerprint,
                    createdAt: recoverySheetCreatedAt,
                    installsKey: recoverySheetInstallsKey,
                    currentFingerprint: recoverySheetCurrentFingerprint,
                    onInstall: installGeneratedRecoveryKey
                )
            }
            .onChange(of: showRecoverySheet) { _, isPresented in
                if !isPresented { recoverySheetKey = "" }
            }
            .confirmationDialog(
                "Stop using the active recovery key for new backups?",
                isPresented: $confirmStopActive,
                titleVisibility: .visible
            ) {
                Button("Keep for restores") { env.stopUsingActiveRecoveryKey() }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Existing protected backups still require this recovery key. New backups will use only the sync passphrase. The key stays installed for restores.")
            }
            .confirmationDialog(
                "Replace the active recovery key?",
                isPresented: $confirmReplaceActive,
                titleVisibility: .visible
            ) {
                Button("Replace and keep the old key for restores") { applyPendingActiveReplacement() }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text(replaceActiveMessage)
            }
            .confirmationDialog(
                "Remove this retained recovery key?",
                isPresented: $confirmRemoveRetained,
                titleVisibility: .visible
            ) {
                Button("Remove retained key", role: .destructive) { removePendingRetainedKey() }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text(removeRetainedMessageText)
            }
    }

    var replaceActiveMessage: String {
        let current = env.cachedRecoveryKeys.first(where: \.isActive)?.fingerprint ?? "none"
        let incoming: String
        if let identifier = pendingPromoteIdentifier,
           let summary = env.cachedRecoveryKeys.first(where: { $0.identifier == identifier }) {
            incoming = summary.fingerprint
        } else if let fingerprint = try? CloudRecoveryKey.fingerprint(forKey: pendingEnteredActiveKey) {
            incoming = fingerprint
        } else {
            incoming = "new key"
        }
        return "Current key: \(current). New key: \(incoming). Existing backups still require their original keys. The current key will remain available for restores."
    }

    var removeRetainedMessage: String {
        guard let identifier = pendingRemoveIdentifier else {
            return "This key will be removed from this Mac."
        }
        let fingerprint = env.cachedRecoveryKeys.first { $0.identifier == identifier }?.fingerprint
            ?? CloudRecoveryKey.fingerprint(identifier: identifier)
        let dependents = env.dependentBundles(for: identifier)
        var message = "\(dependents.matchingCount) known backup\(dependents.matchingCount == 1 ? "" : "s") still require \(fingerprint)."
        if dependents.legacyUnattributedCount > 0 {
            message += " Some older backups may still require it because they do not record a key identity."
        }
        return message
    }
}
