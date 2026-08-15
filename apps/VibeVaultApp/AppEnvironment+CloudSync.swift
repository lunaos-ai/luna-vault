import AppKit
import Foundation
import VaultCore

struct AppCloudSyncStatus: Equatable {
    let localCount: Int
    let path: String
    let iCloudRootPath: String
    let iCloudAvailable: Bool
    let bundleExists: Bool
    let sizeText: String
    let modifiedText: String
}

struct AppCloudSyncPreview: Equatable {
    let path: String
    let sourceHost: String
    let exportedAtText: String
    let secretCount: Int
    let revisionCount: Int
    let authenticatorCount: Int
    let sizeText: String
    let newCount: Int
    let backupNewerCount: Int
    let localNewerCount: Int
    let sameTimestampCount: Int
}

enum AppCloudSyncImportPolicy: String, CaseIterable, Identifiable {
    case keepLocal
    case backupNewer
    case replaceAll

    var id: String { rawValue }

    var label: String {
        switch self {
        case .keepLocal: return "Keep local"
        case .backupNewer: return "Use newer"
        case .replaceAll: return "Replace all"
        }
    }
}

extension AppEnvironment {
    static let automaticBackupPassphraseKey = "cloud-backup-passphrase"
    static let backupRecoveryKeyKey = CloudRecoveryKey.preferenceKey

    func cloudSyncStatus() -> AppCloudSyncStatus {
        let url = CloudSync.defaultICloudURL()
        let rootURL = CloudSync.iCloudDriveRootURL()
        let attrs = try? FileManager.default.attributesOfItem(atPath: url.path)
        let size = (attrs?[.size] as? NSNumber)?.int64Value ?? 0
        let modified = attrs?[.modificationDate] as? Date
        return AppCloudSyncStatus(
            localCount: secrets.count,
            path: url.path,
            iCloudRootPath: rootURL.path,
            iCloudAvailable: CloudSync.isICloudDriveAvailable(at: rootURL),
            bundleExists: FileManager.default.fileExists(atPath: url.path),
            sizeText: size > 0 ? ByteCountFormatter.string(fromByteCount: size, countStyle: .file) : "-",
            modifiedText: modified?.formatted(date: .abbreviated, time: .shortened) ?? "-"
        )
    }

    func pushCloudSync(passphrase: String) async -> Bool {
        guard cloudSyncStatus().iCloudAvailable else {
            showToast("Enable iCloud Drive in System Settings", feedback: .caution)
            return false
        }
        return await pushCloudSync(
            to: CloudSync.defaultICloudURL(),
            passphrase: passphrase,
            destinationName: "iCloud"
        )
    }

    func openAppleAccountSettings() {
        let candidates = [
            "x-apple.systempreferences:com.apple.systempreferences.AppleIDSettings",
            "x-apple.systempreferences:com.apple.preferences.icloud"
        ]
        for candidate in candidates {
            guard let url = URL(string: candidate) else { continue }
            if NSWorkspace.shared.open(url) { return }
        }
        NSWorkspace.shared.open(
            URL(fileURLWithPath: "/System/Applications/System Settings.app")
        )
    }

    func openICloudDrive() {
        let status = cloudSyncStatus()
        guard status.iCloudAvailable else {
            showToast("iCloud Drive is not available on this Mac", feedback: .caution)
            return
        }
        let bundleURL = CloudSync.defaultICloudURL()
        let target = FileManager.default.fileExists(atPath: bundleURL.path)
            ? bundleURL
            : CloudSync.iCloudDriveRootURL()
        NSWorkspace.shared.activateFileViewerSelecting([target])
    }

    func pushCloudSync(to url: URL, passphrase: String, destinationName: String) async -> Bool {
        do {
            let snapshot = try await cloudSyncSnapshot()
            let data = try CloudSync.encrypt(
                snapshot,
                passphrase: passphrase,
                recoveryKey: backupRecoveryKey()
            )
            try CloudSync.write(data, to: url)
            showToast("Synced \(snapshot.secrets.count) secrets to \(destinationName)")
            return true
        } catch {
            lastError = "\(error)"
            showToast("Cloud sync failed", feedback: .caution)
            return false
        }
    }
}
