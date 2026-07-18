import SwiftUI
import VaultCore

struct MainWindow: View {
    @EnvironmentObject var env: AppEnvironment
    @State private var selection: SidebarItem = .overview
    @State private var showOnboarding = false
    @State private var showAddSecret = false

    var body: some View {
        NavigationSplitView {
            MainSidebar(selection: $selection)
                .environmentObject(env)
                .navigationSplitViewColumnWidth(min: 200, ideal: 224, max: 280)
        } detail: {
            detail
                .background(Tokens.Surface.background.ignoresSafeArea())
        }
        .toast($env.toastMessage)
        .sheet(isPresented: $showAddSecret) {
            AddSecretSheet().environmentObject(env)
        }
        .task {
            env.refresh()
            env.refreshAudit()
            showOnboarding = env.needsOnboarding
            if ProcessInfo.processInfo.environment["VIBEVAULT_UX_SMOKE"] == "1" {
                showOnboarding = false
                try? await Task.sleep(nanoseconds: 600_000_000)
                await UXSmokeTour.run(setSelection: { selection = $0 }, env: env)
            }
        }
        .onChange(of: selection) { _, _ in
            Feedback.play(.select, soundsEnabled: env.uiSoundsEnabled)
        }
        .onChange(of: env.onboardingOpenProjects) { _, open in
            if open { selection = .projects; env.onboardingOpenProjects = false }
        }
        .onChange(of: env.openCloudflare) { _, open in
            if open {
                env.pendingProviderTab = "cloudflare"
                selection = .providers
                env.openCloudflare = false
            }
        }
        .onChange(of: env.openPushci) { _, open in
            if open {
                env.pendingProviderTab = "pushci"
                selection = .providers
                env.openPushci = false
            }
        }
        .onChange(of: env.openAddSecret) { _, open in
            if open {
                selection = .vault
                showAddSecret = true
                env.openAddSecret = false
            }
        }
        .onChange(of: env.focusVaultSearch) { _, focus in
            if focus { selection = .vault }
        }
        .onChange(of: env.openVaultHighlight) { _, name in
            if name != nil { selection = .vault }
        }
        .onChange(of: env.openAIAgents) { _, open in
            if open { selection = .aiAgents; env.openAIAgents = false }
        }
        .onReceive(NotificationCenter.default.publisher(for: .runUXSmokeTour)) { _ in
            Task {
                showOnboarding = false
                await UXSmokeTour.run(setSelection: { selection = $0 }, env: env)
            }
        }
        .sheet(isPresented: $showOnboarding) {
            OnboardingScene(
                onScanProject: {
                    env.completeOnboarding(openProjects: true)
                    showOnboarding = false
                },
                onOpenVault: {
                    env.completeOnboarding()
                    selection = .overview
                    showOnboarding = false
                },
                onConnectAgents: {
                    env.completeOnboarding()
                    env.openAIAgents = true
                    showOnboarding = false
                }
            )
            .environmentObject(env)
            .interactiveDismissDisabled()
        }
    }

    @ViewBuilder
    private var detail: some View {
        switch selection {
        case .overview:
            VaultOverviewView(
                onScan: { selection = .projects },
                onImport: { selection = .importSecrets },
                onCloudflare: { selection = .providers },
                onAIAgents: { selection = .aiAgents },
                onAudit: { selection = .audit },
                onAdd: { showAddSecret = true }
            )
            .environmentObject(env)
        case .vault:
            VaultListView(
                highlightName: env.openVaultHighlight,
                onHighlightHandled: { env.openVaultHighlight = nil },
                onScanProject: { selection = .projects },
                onOpenImport: { selection = .importSecrets }
            )
        case .importSecrets: ImportView()
        case .projects: ProjectScannerView()
        case .audit: AuditLogView()
        case .providers: ProvidersHubView()
        case .aiAgents: AIAgentsView()
        case .settings: SettingsView()
        }
    }
}
