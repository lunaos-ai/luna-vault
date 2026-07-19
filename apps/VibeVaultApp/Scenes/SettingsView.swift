import SwiftUI
import VaultCore

struct SettingsView: View {
    @EnvironmentObject var env: AppEnvironment

    var body: some View {
        Form {
            SessionTrustSection()

            Section {
                Toggle("Background expiry notifications", isOn: $env.notificationsEnabled)
                if env.notificationsEnabled {
                    Stepper(
                        "Warn within \(env.warnWithinDays) day\(env.warnWithinDays == 1 ? "" : "s")",
                        value: $env.warnWithinDays, in: 1...90
                    )
                }
                LabeledContent("Last check", value: env.lastNotifierRun)
                HStack {
                    Button { Task { await env.runExpiryCheckNow() } } label: {
                        Label("Check now", systemImage: "bell.badge")
                    }
                    Button(role: .destructive) { env.resetNotificationDedupe() } label: {
                        Label("Reset reminders", systemImage: "arrow.counterclockwise")
                    }
                    .help("Clears the delivered-alerts log so previously-sent notifications fire again.")
                }
            } header: {
                Text("Notifications")
            } footer: {
                Text("Posts a macOS notification when a secret expires or is due for rotation. Runs hourly while the app is open.")
            }

            Section {
                Toggle("UI sounds", isOn: $env.uiSoundsEnabled)
                Button("Preview success sound") {
                    Feedback.play(.success, soundsEnabled: true)
                }
                .disabled(!env.uiSoundsEnabled)
                Button("Run UX walkthrough") {
                    NotificationCenter.default.post(name: .runUXSmokeTour, object: nil)
                }
            } header: {
                Text("Feedback")
            } footer: {
                Text("Quiet system clicks on copy, prepare, and sync. Walkthrough visits every sidebar pane with motion and toasts.")
            }

            TeamLicenseSection()
            CloudSyncSettingsSection()
            CloudflareSettingsSection()
            VercelSettingsSection()
            PushciSettingsSection()

            Section {
                LabeledContent("Secrets", value: "Encrypted vault (master key in Keychain)")
                LabeledContent("Settings storage", value: "Keychain (\(KeychainPrefs.service))")
                LabeledContent("Audit DB", value: "~/Library/Application Support/vibe-vault/audit.db")
                Text("Records older than 90 days are auto-purged. Override in CLI: `vibevault purge --days N`.")
                    .foregroundStyle(.secondary)
            } header: {
                Text("Storage")
            } footer: {
                Text("Ciphertext on disk (excluded from iCloud backup). Master key and prefs in Keychain. Audit log is SQLite.")
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
        .background(.regularMaterial)
        .navigationTitle("Settings")
    }
}
