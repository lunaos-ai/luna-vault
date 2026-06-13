import SwiftUI
import VaultCore

struct MainWindow: View {
    @EnvironmentObject var env: AppEnvironment
    @EnvironmentObject var nav: Navigator
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    enum SidebarItem: String, Hashable, CaseIterable, Identifiable {
        case vault, importSecrets = "import", projects, audit, providers, aiAgents = "ai-agents", settings
        var id: String { rawValue }
        var label: String {
            switch self {
            case .vault: return "Vault"
            case .importSecrets: return "Import"
            case .projects: return "Projects"
            case .audit: return "Audit"
            case .providers: return "Providers"
            case .aiAgents: return "AI Agents"
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
            case .aiAgents: return "sparkles"
            case .settings: return "gearshape"
            }
        }
        var tint: Color { Tokens.Text.secondary }
        var section: String {
            switch self {
            case .vault, .importSecrets: return "Library"
            case .projects, .providers, .aiAgents: return "Workflows"
            case .audit, .settings: return "System"
            }
        }
    }

    private var sections: [String] {
        ["Library", "Workflows", "System"]
    }

    var body: some View {
        NavigationSplitView {
            sidebar
                .navigationSplitViewColumnWidth(min: 200, ideal: 224, max: 280)
        } detail: {
            detail
                .background(LiquidBackdrop())
        }
        .background {
            Button("") { nav.togglePalette() }
                .keyboardShortcut("k", modifiers: .command)
                .opacity(0)
                .accessibilityHidden(true)
        }
        .overlay {
            if nav.paletteOpen {
                CommandPaletteView()
            }
        }
        .animation(reduceMotion ? nil : Tokens.Motion.snappy, value: nav.paletteOpen)
        .task { env.refresh(); env.refreshAudit() }
    }

    private var sidebar: some View {
        List(selection: $nav.section) {
            ForEach(sections, id: \.self) { section in
                Section {
                    ForEach(SidebarItem.allCases.filter { $0.section == section }) { item in
                        sidebarRow(item).tag(item)
                    }
                } header: {
                    Text(section)
                        .font(.caption2.weight(.semibold))
                        .textCase(.uppercase)
                        .tracking(0.6)
                        .foregroundStyle(Tokens.Text.tertiary)
                        .padding(.top, Tokens.Space.xs)
                }
            }
        }
        .listStyle(.sidebar)
        .scrollContentBackground(.hidden)
        .background(.regularMaterial)
        .navigationTitle("Vibe Vault")
        .safeAreaInset(edge: .top) { sidebarBrand }
        .safeAreaInset(edge: .bottom) { footer }
    }

    private var sidebarBrand: some View {
        HStack(spacing: Tokens.Space.sm) {
            ZStack {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(Tokens.Palette.accent.opacity(0.14))
                    .frame(width: 24, height: 24)
                Image(systemName: "key.fill")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Tokens.Palette.accent)
            }
            VStack(alignment: .leading, spacing: 0) {
                Text("Vibe Vault").font(.system(size: 13, weight: .semibold)).tracking(-0.2)
                Text("Local Keychain")
                    .font(.system(size: 10))
                    .foregroundStyle(Tokens.Text.tertiary)
            }
            Spacer()
        }
        .padding(.horizontal, Tokens.Space.md)
        .padding(.top, Tokens.Space.sm)
        .padding(.bottom, Tokens.Space.xs)
    }

    private func sidebarRow(_ item: SidebarItem) -> some View {
        Label(item.label, systemImage: item.systemImage)
            .font(.system(size: 13))
            .padding(.vertical, 1)
            .accessibilityLabel(item.label)
    }

    private var footer: some View {
        let unlocked = env.biometricStatus.lowercased().contains("unlock") || env.biometricStatus == "Idle"
        return HStack(spacing: Tokens.Space.sm) {
            Image(systemName: unlocked ? "lock.open.fill" : "lock.fill")
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(unlocked ? Tokens.Status.success.opacity(0.85) : Tokens.Status.warning)
            Text(unlocked ? "Session unlocked" : "Locked. Touch ID required.")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Tokens.Text.secondary)
            Spacer()
            Text("v0.1")
                .font(.system(size: 10))
                .foregroundStyle(Tokens.Text.tertiary)
        }
        .padding(.horizontal, Tokens.Space.md)
        .padding(.vertical, Tokens.Space.sm)
        .background(.thinMaterial)
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private var detail: some View {
        switch nav.section {
        case .vault: VaultListView()
        case .importSecrets: ImportView()
        case .projects: ProjectScannerView()
        case .audit: AuditLogView()
        case .providers: ProviderSyncView()
        case .aiAgents: AIAgentsView()
        case .settings: SettingsView()
        }
    }
}
