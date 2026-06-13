import SwiftUI
import VaultCore

struct SettingsView: View {
    @EnvironmentObject var env: AppEnvironment
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var cloudAuth: CloudAuthService

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Tokens.Space.xl) {
                appearanceSection
                touchIDSection
                notificationsSection
                cloudSection
                storageSection
            }
            .padding(Tokens.Space.xl)
            .frame(maxWidth: 620, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
        .scrollContentBackground(.hidden)
        .background(LiquidBackdrop())
        .navigationTitle("Settings")
    }

    private var appearanceSection: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.md) {
            Text("Appearance").sectionLabel()
            
            Picker("Theme", selection: $themeManager.currentTheme) {
                ForEach(ThemeManager.Theme.allCases) { theme in
                    Label(theme.displayName, systemImage: theme.icon)
                        .tag(theme)
                }
            }
            .pickerStyle(.segmented)
            
            Text("Choose between light, dark, or follow system preference.")
                .font(.footnote)
                .foregroundStyle(Tokens.Text.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard()
    }

    private var touchIDSection: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.md) {
            Text("Touch ID session").sectionLabel()

            Toggle("Trust this session (until app quits)", isOn: $env.trustSession)
            Stepper(
                "Re-prompt every \(Int(env.biometricSessionMinutes)) minute(s)",
                value: $env.biometricSessionMinutes,
                in: 1...60
            )
            .disabled(env.trustSession)
            LabeledContent("Status", value: env.biometricStatus)

            HStack(spacing: Tokens.Space.sm) {
                Button { Task { await env.testBiometric() } } label: {
                    Label("Test Touch ID", systemImage: "touchid")
                }
                .buttonStyle(.glass)
                .accessibilityLabel("Test Touch ID")

                Button { env.resetBiometricSession() } label: {
                    Label("Lock session", systemImage: "lock.fill")
                }
                .buttonStyle(.glass(tint: Tokens.Status.danger))
                .accessibilityLabel("Lock session")
            }
            .padding(.top, Tokens.Space.xs)

            Text("Lower = safer; higher = fewer prompts during long sessions.")
                .font(.footnote)
                .foregroundStyle(Tokens.Text.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard()
    }

    private var notificationsSection: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.md) {
            Text("Notifications").sectionLabel()

            Toggle("Background expiry notifications", isOn: $env.notificationsEnabled)
            if env.notificationsEnabled {
                Stepper(
                    "Warn within \(env.warnWithinDays) day\(env.warnWithinDays == 1 ? "" : "s")",
                    value: $env.warnWithinDays, in: 1...90
                )
            }
            LabeledContent("Last check", value: env.lastNotifierRun)

            HStack(spacing: Tokens.Space.sm) {
                Button { Task { await env.runExpiryCheckNow() } } label: {
                    Label("Check now", systemImage: "bell.badge")
                }
                .buttonStyle(.glass)
                .accessibilityLabel("Check now")

                Button { env.resetNotificationDedupe() } label: {
                    Label("Reset reminders", systemImage: "arrow.counterclockwise")
                }
                .buttonStyle(.glass(tint: Tokens.Status.danger))
                .accessibilityLabel("Reset reminders")
                .help("Clears the delivered-alerts log so previously-sent notifications fire again.")
            }
            .padding(.top, Tokens.Space.xs)

            Text("Posts a macOS notification when a secret expires or is due for rotation. Runs hourly while the app is open.")
                .font(.footnote)
                .foregroundStyle(Tokens.Text.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard()
    }

    private var cloudSection: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.md) {
            Text("Cloud (optional)").sectionLabel()

            Toggle("Enable cloud features", isOn: Binding(
                get: { cloudAuth.cloudEnabled },
                set: { cloudAuth.setCloudEnabled($0) }
            ))
            if cloudAuth.cloudEnabled {
                LabeledContent("Account",
                               value: cloudAuth.isAuthenticated ? (cloudAuth.userEmail ?? "Signed in") : "Not signed in")
            }

            Text("Off by default. Vibe Vault makes no network calls until you turn this on; turning it off signs out and stops all cloud activity. Auth tokens are stored in your Keychain.")
                .font(.footnote)
                .foregroundStyle(Tokens.Text.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard()
    }

    private var storageSection: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.md) {
            Text("Storage").sectionLabel()

            LabeledContent("Settings storage", value: "Keychain (\(KeychainPrefs.service))")
            LabeledContent("Audit DB", value: "~/Library/Application Support/vibe-vault/audit.db")
            Text("Records older than 90 days are auto-purged. Override in CLI: `vibevault purge --days N`.")
                .foregroundStyle(Tokens.Text.secondary)

            Text("Secrets and preferences live in your login Keychain, encrypted by macOS. The audit log lives on disk as SQLite for fast queries.")
                .font(.footnote)
                .foregroundStyle(Tokens.Text.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard()
    }
}
