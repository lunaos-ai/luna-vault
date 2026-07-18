import SwiftUI

enum SidebarItem: String, Hashable, CaseIterable, Identifiable {
    case overview, vault, importSecrets = "import", projects, audit, providers, aiAgents = "ai-agents", settings
    var id: String { rawValue }
    var label: String {
        switch self {
        case .overview: return "Overview"
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
        case .overview: return "square.grid.2x2.fill"
        case .vault: return "key.fill"
        case .importSecrets: return "square.and.arrow.down"
        case .projects: return "folder.badge.questionmark"
        case .audit: return "list.bullet.rectangle"
        case .providers: return "cloud.fill"
        case .aiAgents: return "sparkles.rectangle.stack"
        case .settings: return "gearshape"
        }
    }
    var section: String {
        switch self {
        case .overview, .vault, .importSecrets: return "Library"
        case .projects, .providers, .aiAgents: return "Workflows"
        case .audit, .settings: return "System"
        }
    }
    static let sections = ["Library", "Workflows", "System"]
}

struct MainSidebar: View {
    @EnvironmentObject var env: AppEnvironment
    @Binding var selection: SidebarItem

    var body: some View {
        List(selection: $selection) {
            ForEach(SidebarItem.sections, id: \.self) { section in
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
        .safeAreaInset(edge: .bottom) { SidebarStatusFooter().environmentObject(env) }
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
                Text("Local vault")
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
        HStack(spacing: Tokens.Space.sm) {
            Image(systemName: item.systemImage)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(selection == item ? Tokens.Palette.accent : Tokens.Text.secondary)
                .symbolEffect(.bounce, value: selection == item)
                .frame(width: 18)
            Text(item.label)
                .font(.system(size: 13, weight: selection == item ? .semibold : .regular))
            Spacer()
        }
        .padding(.vertical, 3)
        .contentShape(Rectangle())
        .accessibilityLabel(item.label)
    }
}
