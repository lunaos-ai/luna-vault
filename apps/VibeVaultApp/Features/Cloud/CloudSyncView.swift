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
}
