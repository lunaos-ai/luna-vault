import SwiftUI
import VaultCore

struct CloudSyncView: View {
    @EnvironmentObject var env: AppEnvironment
    @State private var status: AppCloudSyncStatus?

    var body: some View {
        Form {
            Section {
                syncRoute

                LabeledContent("Apple Account", value: accountStatusText)
                LabeledContent("iCloud bundle", value: bundleStatusText)

                Text(accountExplanation)
                    .font(.callout)
                    .foregroundStyle(Tokens.Text.secondary)

                HStack {
                    accountButton

                    Button {
                        env.openICloudDrive()
                    } label: {
                        Label("Open iCloud Drive", systemImage: "folder")
                    }
                    .disabled(status?.iCloudAvailable != true)

                    Button {
                        refresh()
                    } label: {
                        Label("Refresh", systemImage: "arrow.clockwise")
                    }
                }

                if let status {
                    Text(status.iCloudRootPath)
                        .font(.caption.monospaced())
                        .foregroundStyle(Tokens.Text.tertiary)
                        .textSelection(.enabled)
                }
            } header: {
                Text("Apple Account and iCloud Drive")
            } footer: {
                Text("Apple Account sign-in is managed by macOS. Vibe Vault never receives your Apple password or Apple Account credentials.")
            }

            setupChecklist

            CloudSyncSettingsSection(onStatusChange: refresh)
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
        .background(.regularMaterial)
        .navigationTitle("Cloud Sync")
        .task { refresh() }
    }

    private var syncRoute: some View {
        HStack(spacing: Tokens.Space.sm) {
            routeNode(icon: "laptopcomputer", label: "This Mac")
            routeArrow
            routeNode(icon: "lock.doc.fill", label: "Encrypted")
            routeArrow
            routeNode(
                icon: status?.iCloudAvailable == true ? "icloud.fill" : "icloud.slash",
                label: "iCloud Drive",
                color: status?.iCloudAvailable == true ? Tokens.Status.success : Tokens.Status.warning
            )
        }
        .padding(.vertical, Tokens.Space.sm)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            status?.iCloudAvailable == true
                ? "Encrypted sync route from this Mac to iCloud Drive is ready"
                : "iCloud Drive needs setup"
        )
    }

    private func routeNode(
        icon: String,
        label: String,
        color: Color = Tokens.Palette.accent
    ) -> some View {
        VStack(spacing: Tokens.Space.xs) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(color)
                .frame(width: 28, height: 24)
            Text(label)
                .font(.caption.weight(.medium))
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
    }

    private var routeArrow: some View {
        Image(systemName: "arrow.right")
            .font(.caption.weight(.semibold))
            .foregroundStyle(Tokens.Text.tertiary)
            .accessibilityHidden(true)
    }

    private var accountStatusText: String {
        status?.iCloudAvailable == true ? "iCloud Drive available" : "Sign in or enable iCloud Drive"
    }

    private var bundleStatusText: String {
        guard let status else { return "Checking" }
        if status.bundleExists { return "Ready to sync between Macs" }
        return status.iCloudAvailable ? "Not created yet" : "Unavailable"
    }

    private var accountExplanation: String {
        if status?.iCloudAvailable == true {
            return "Vibe Vault will encrypt the vault locally before placing the sync bundle in your iCloud Drive."
        }
        return "Open System Settings, sign in to your Apple Account if needed, and turn on iCloud Drive. Then return here and refresh."
    }

    private var accountButtonTitle: String {
        status?.iCloudAvailable == true ? "Manage Apple Account" : "Sign in to Apple Account"
    }

    @ViewBuilder
    private var accountButton: some View {
        if status?.iCloudAvailable == true {
            Button {
                env.openAppleAccountSettings()
            } label: {
                Label(accountButtonTitle, systemImage: "person.crop.circle")
            }
            .buttonStyle(.bordered)
        } else {
            Button {
                env.openAppleAccountSettings()
            } label: {
                Label(accountButtonTitle, systemImage: "person.crop.circle")
            }
            .buttonStyle(.borderedProminent)
        }
    }

    private func refresh() {
        status = env.cloudSyncStatus()
    }

    private var setupChecklist: some View {
        Section {
            checklistRow(
                done: status?.iCloudAvailable == true,
                title: "Apple Account and iCloud Drive",
                detail: "Sign in through System Settings, then Refresh here."
            )
            checklistRow(
                done: env.cachedHasBackupRecoveryKey,
                title: "Recovery key (recommended)",
                detail: "Unlock backups if you forget the sync passphrase."
            )
            checklistRow(
                done: status?.bundleExists == true,
                title: "First sync to iCloud",
                detail: "Enter a 12+ character passphrase, confirm it, then Sync to iCloud."
            )
            checklistRow(
                done: env.automaticBackupsEnabled,
                title: "Scheduled backups (optional)",
                detail: "Enable schedule below. Runs while the app is open and the vault is unlocked."
            )
        } header: {
            Text("Setup checklist")
        } footer: {
            Text("iCloud sync moves secrets between Macs. Export backup creates a portable file. Managed history keeps timestamped copies in iCloud Drive.")
        }
    }

    private func checklistRow(done: Bool, title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: Tokens.Space.sm) {
            Image(systemName: done ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(done ? Tokens.Status.success : Tokens.Text.secondary)
                .padding(.top, 2)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.callout.weight(.medium))
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(Tokens.Text.secondary)
            }
        }
        .accessibilityElement(children: .combine)
    }
}
