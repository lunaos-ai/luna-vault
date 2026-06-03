import SwiftUI
import VaultCore

struct SettingsView: View {
    @EnvironmentObject var env: AppEnvironment

    var body: some View {
        Form {
            Section {
                Toggle("Trust this session (until app quits)", isOn: $env.trustSession)
                Stepper(
                    "Re-prompt every \(Int(env.biometricSessionMinutes)) minute(s)",
                    value: $env.biometricSessionMinutes,
                    in: 1...60
                )
                .disabled(env.trustSession)
                LabeledContent("Status", value: env.biometricStatus)
                HStack {
                    Button { Task { await env.testBiometric() } } label: {
                        Label("Test Touch ID", systemImage: "touchid")
                    }
                    Button(role: .destructive) { env.resetBiometricSession() } label: {
                        Label("Lock session", systemImage: "lock.fill")
                    }
                }
            } header: {
                Text("Touch ID session")
            } footer: {
                Text("Lower = safer; higher = fewer prompts during long sessions.")
            }

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
                LabeledContent("Settings storage", value: "Keychain (\(KeychainPrefs.service))")
                LabeledContent("Audit DB", value: "~/Library/Application Support/vibe-vault/audit.db")
                Text("Records older than 90 days are auto-purged. Override in CLI: `vibevault purge --days N`.")
                    .foregroundStyle(.secondary)
            } header: {
                Text("Storage")
            } footer: {
                Text("Secrets and preferences live in your login Keychain, encrypted by macOS. The audit log lives on disk as SQLite for fast queries.")
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
        .background(.regularMaterial)
        .navigationTitle("Settings")
    }
}
