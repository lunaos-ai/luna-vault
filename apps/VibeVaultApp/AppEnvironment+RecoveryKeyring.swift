import Foundation
import VaultCore

extension AppEnvironment {
    func loadedRecoveryKeyring() -> RecoveryKeyring {
        RecoveryKeyringStore.load(from: prefs)
    }

    func refreshRecoveryKeyCache() {
        let keyring = loadedRecoveryKeyring()
        cachedHasBackupRecoveryKey = keyring.activeCanonicalKey != nil
        cachedRecoveryKeys = keyring.summaries
    }

    func persistRecoveryKeyring(_ keyring: RecoveryKeyring) throws {
        RecoveryKeyringStore.save(keyring, to: prefs)
        refreshRecoveryKeyCache()
    }

    func keepRecoveryKeyForRestores(_ recoveryKey: String) throws {
        var keyring = loadedRecoveryKeyring()
        try keyring.addRetained(recoveryKey)
        try persistRecoveryKeyring(keyring)
        showToast("Recovery key kept for restoring older backups")
    }

    func makeRecoveryKeyActive(_ recoveryKey: String, imported: Bool = true) throws {
        let canonical = try CloudRecoveryKey.canonicalize(recoveryKey)
        try LocalVaultRecovery.protect(
            directory: EncryptedVaultStore.defaultDirectory(),
            recoveryKey: canonical
        )
        var keyring = loadedRecoveryKeyring()
        try keyring.makeActive(canonical, imported: imported)
        try persistRecoveryKeyring(keyring)
        showToast("Active recovery key updated for new backups")
    }

    func stopUsingActiveRecoveryKey() {
        var keyring = loadedRecoveryKeyring()
        keyring.clearActive()
        try? persistRecoveryKeyring(keyring)
        showToast("Recovery protection removed from future backups", feedback: .tick)
    }

    func removeRetainedRecoveryKey(identifier: String) throws {
        var keyring = loadedRecoveryKeyring()
        try keyring.removeRetained(identifier: identifier)
        try persistRecoveryKeyring(keyring)
        showToast("Retained recovery key removed", feedback: .tick)
    }

    func dependentBundles(for identifier: String) -> RecoveryKeyDependents {
        RecoveryKeyBundleScanner.scan(identifier: identifier, urls: knownBackupURLs())
    }

    func knownBackupURLs() -> [URL] {
        var urls: [URL] = []
        let icloud = CloudSync.defaultICloudURL()
        if FileManager.default.fileExists(atPath: icloud.path) {
            urls.append(icloud)
        }
        if let history = try? CloudBackupArchive.list() {
            urls.append(contentsOf: history.map(\.url))
        }
        return urls
    }

    func revealRecoveryKey(identifier: String) async throws -> String {
        try await service.biometric.authenticate(reason: "Show the Vibe Vault recovery key")
        guard let record = loadedRecoveryKeyring().record(identifier: identifier) else {
            throw RecoveryKeyringError.keyNotFound
        }
        return record.canonicalKey
    }

    func inspectCloudSyncBundle(at url: URL) throws -> CloudSyncBundleInfo {
        try CloudSync.inspect(Data(contentsOf: url))
    }
}
