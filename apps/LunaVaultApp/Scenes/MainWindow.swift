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
            case .importSecrets: return "Import"
            default: return rawValue.capitalized
            }
        }
        var systemImage: String {
            switch self {
            case .vault: return "key.fill"
            case .importSecrets: return "square.and.arrow.down"
            case .projects: return "folder.badge.questionmark"
            case .audit: return "list.bullet.rectangle"
            case .providers: return "icloud.and.arrow.up"
            case .settings: return "gear"
            }
        }
    }

    var body: some View {
        NavigationSplitView {
            List(SidebarItem.allCases, selection: $selection) { item in
                Label(item.label, systemImage: item.systemImage).tag(item)
            }
            .navigationSplitViewColumnWidth(min: 160, ideal: 200, max: 240)
        } detail: {
            detail
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Tokens.Color.surface)
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
            Section("Touch ID session") {
                Stepper(
                    "Re-prompt every \(Int(env.biometricSessionMinutes)) minute(s)",
                    value: $env.biometricSessionMinutes,
                    in: 1...60
                )
                Text("Lower = safer; higher = fewer prompts during long sessions.")
                    .font(.caption)
                    .foregroundStyle(Tokens.Color.textSecondary)

                HStack(spacing: Tokens.Space.md) {
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
                HStack {
                    Image(systemName: "info.circle")
                        .foregroundStyle(Tokens.Color.textSecondary)
                    Text(env.biometricStatus)
                        .font(.caption)
                        .foregroundStyle(Tokens.Color.textSecondary)
                }
            }
            Section("Audit retention") {
                Text("Records older than 90 days are auto-purged. Override in CLI: `lunavault purge --days N`.")
                    .foregroundStyle(Tokens.Color.textSecondary)
            }
        }
        .formStyle(.grouped)
        .padding(Tokens.Space.xl)
    }
}
