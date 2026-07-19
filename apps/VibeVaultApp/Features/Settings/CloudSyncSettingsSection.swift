import SwiftUI
import VaultCore

struct CloudSyncSettingsSection: View {
    @EnvironmentObject var env: AppEnvironment
    @State private var passphrase = ""
    @State private var confirmation = ""
    @State private var overwrite = false
    @State private var isWorking = false
    @State private var status: AppCloudSyncStatus?

    private var canPush: Bool {
        passphrase.count >= 12 && passphrase == confirmation && !isWorking
    }

    private var canPull: Bool {
        passphrase.count >= 12 && !isWorking && (status?.bundleExists ?? false)
    }

    var body: some View {
        Section {
            if let status {
                LabeledContent("Local secrets", value: "\(status.localCount)")
                LabeledContent("iCloud bundle", value: status.bundleExists ? "Present" : "Missing")
                LabeledContent("Updated", value: status.modifiedText)
                LabeledContent("Size", value: status.sizeText)
            }

            SecureField("Sync passphrase", text: $passphrase)
            SecureField("Confirm passphrase", text: $confirmation)

            Toggle("Overwrite matching names on import", isOn: $overwrite)

            HStack {
                Button {
                    Task { await push() }
                } label: {
                    Label("Sync to iCloud", systemImage: "icloud.and.arrow.up")
                }
                .disabled(!canPush)

                Button {
                    Task { await pull() }
                } label: {
                    Label("Import from iCloud", systemImage: "icloud.and.arrow.down")
                }
                .disabled(!canPull)

                Button {
                    refreshStatus()
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
                .disabled(isWorking)
            }

            if let status {
                Text(status.path)
                    .font(.caption)
                    .foregroundStyle(Tokens.Text.secondary)
                    .textSelection(.enabled)
            }
        } header: {
            Text("Cloud Sync")
        } footer: {
            Text("Encrypted iCloud Drive bundle. The passphrase is not saved.")
        }
        .onAppear { refreshStatus() }
    }

    private func refreshStatus() {
        status = env.cloudSyncStatus()
    }

    private func push() async {
        guard canPush else { return }
        isWorking = true
        defer {
            isWorking = false
            refreshStatus()
        }
        if await env.pushCloudSync(passphrase: passphrase) {
            confirmation = ""
        }
    }

    private func pull() async {
        guard canPull else { return }
        isWorking = true
        defer {
            isWorking = false
            refreshStatus()
        }
        _ = await env.pullCloudSync(passphrase: passphrase, overwrite: overwrite)
    }
}
