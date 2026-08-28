import Foundation
import VaultCore

/// Drives Cloud Sync + Team license screens and writes results for `scripts/tests/cloud-sync-team-ui-smoke.sh`.
@MainActor
enum CloudSyncTeamUISmoke {
    static let resultPath = "/tmp/vibevault-ui-smoke-result.json"

    static func run(
        setSelection: @escaping (SidebarItem) -> Void,
        env: AppEnvironment
    ) async {
        var lines: [String] = []
        func record(_ key: String, _ value: String) {
            lines.append("\"\(escapeJSON(key))\":\"\(escapeJSON(value))\"")
        }

        let passphrase = ProcessInfo.processInfo.environment["VIBEVAULT_UI_SMOKE_PASSPHRASE"]
            ?? "ui-smoke-sync-passphrase"

        env.refreshSharedUnlockSessionStatus()
        record("session_unlocked", env.sessionUnlocked ? "yes" : "no")

        setSelection(.cloudSync)
        env.showToast("UI smoke · Cloud Sync", feedback: .tick)
        try? await Task.sleep(nanoseconds: 900_000_000)
        record("cloud_sync_ui", "ok")

        let before = env.cloudSyncStatus()
        record("icloud_before", before.bundleExists ? "present" : "missing")
        record("icloud_available", before.iCloudAvailable ? "yes" : "no")
        record("local_secrets", "\(before.localCount)")

        let pushed: Bool
        if env.sessionUnlocked {
            pushed = await env.pushCloudSync(passphrase: passphrase)
            record("icloud_push", pushed ? "ok" : "failed")
        } else {
            pushed = false
            record("icloud_push", "skipped_session_locked")
        }
        let after = env.cloudSyncStatus()
        record("icloud_after", after.bundleExists ? "present" : "missing")

        if after.bundleExists, env.sessionUnlocked || pushed {
            do {
                let preview = try env.previewCloudSyncBundle(
                    at: CloudSync.defaultICloudURL(),
                    passphrase: passphrase
                )
                record("preview_secrets", "\(preview.secretCount)")
            } catch {
                record("preview", "failed:\(error)")
            }
        }

        setSelection(.settings)
        env.showToast("UI smoke · Team license", feedback: .tick)
        try? await Task.sleep(nanoseconds: 900_000_000)

        record("team_licensed", env.isTeamLicensed ? "yes" : "no")
        record("team_status", env.licenseStatusLine)
        record("checkout_url", LemonSqueezyConfig.checkoutURL(prefs: env.prefs).absoluteString)
        record("team_ui", "ok")

        let payload = "{\(lines.joined(separator: ","))}\n"
        try? payload.write(toFile: resultPath, atomically: true, encoding: .utf8)
        env.showToast("UI smoke finished · \(resultPath)", feedback: .success)
    }

    private static func escapeJSON(_ value: String) -> String {
        value
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
    }
}
