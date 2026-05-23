import SwiftUI
import VaultCore

struct MainWindow: View {
    @EnvironmentObject var env: AppEnvironment
    @State private var selection: SidebarItem = .vault

    enum SidebarItem: String, Hashable, CaseIterable, Identifiable {
        case vault, importSecrets = "import", projects, audit, providers, settings
        var id: String { rawValue }
        var label: String {
            switch self {
            case .vault: return "Vault"
            case .importSecrets: return "Import"
            case .projects: return "Projects"
            case .audit: return "Audit"
            case .providers: return "Providers"
            case .settings: return "Settings"
            }
        }
        var systemImage: String {
            switch self {
            case .vault: return "key.fill"
            case .importSecrets: return "square.and.arrow.down"
            case .projects: return "folder.badge.questionmark"
            case .audit: return "list.bullet.rectangle"
            case .providers: return "icloud.and.arrow.up"
            case .settings: return "gearshape"
            }
        }
    }

    var body: some View {
        NavigationSplitView {
            List(SidebarItem.allCases, selection: $selection) { item in
                Label(item.label, systemImage: item.systemImage).tag(item)
            }
            .navigationSplitViewColumnWidth(min: 180, ideal: 200, max: 240)
            .navigationTitle("Vibe Vault")
        } detail: {
            detail
        }
        .task { env.refresh(); env.refreshAudit() }
    }

    @ViewBuilder
    private var detail: some View {
        switch selection {
        case .vault: VaultListView()
        case .importSecrets: ImportView()
        case .projects: ProjectScannerView()
        case .audit: AuditLogView()
        case .providers: ProviderSyncView()
        case .settings: SettingsView()
        }
    }
}

struct SettingsView: View {
    @EnvironmentObject var env: AppEnvironment

    var body: some View {
        Form {
            Section {
                Stepper(
                    "Re-prompt every \(Int(env.biometricSessionMinutes)) minute(s)",
                    value: $env.biometricSessionMinutes,
                    in: 1...60
                )
                LabeledContent("Status", value: env.biometricStatus)
                HStack {
                    Button {
                        Task { await env.testBiometric() }
                    } label: {
                        Label("Test Touch ID", systemImage: "touchid")
                    }
                    Button(role: .destructive) {
                        env.resetBiometricSession()
                    } label: {
                        Label("Lock session", systemImage: "lock.fill")
                    }
                }
            } header: {
                Text("Touch ID session")
            } footer: {
                Text("Lower = safer; higher = fewer prompts during long sessions.")
            }
            Section {
                Text("Records older than 90 days are auto-purged. Override in CLI: `vibevault purge --days N`.")
                    .foregroundStyle(.secondary)
            } header: {
                Text("Audit retention")
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Settings")
    }
}
