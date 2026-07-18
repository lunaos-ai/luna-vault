import SwiftUI
import VaultCore

struct VaultListView: View {
    @EnvironmentObject var env: AppEnvironment
    @State private var selection: Secret.ID?
    @State private var showAdd = false
    @State private var search = ""
    @State private var filter: Filter = .all
    var highlightName: String? = nil
    var onHighlightHandled: (() -> Void)? = nil
    var onScanProject: (() -> Void)? = nil
    var onOpenImport: (() -> Void)? = nil

    enum Filter: String, CaseIterable, Identifiable {
        case all, expiring, rotateDue = "rotate", mcp
        var id: String { rawValue }
        var label: String {
            switch self {
            case .all: return "All"
            case .expiring: return "Expiring"
            case .rotateDue: return "Rotate due"
            case .mcp: return "AI-allowed"
            }
        }
    }

    private var filtered: [Secret] {
        let base = env.secrets.filter { s in
            switch filter {
            case .all: return true
            case .expiring: return s.isExpired || (s.expiresAt.map { Calendar.current.dateComponents([.day], from: Date(), to: $0).day ?? 99 } ?? 99) < 14
            case .rotateDue: return s.isRotationDue
            case .mcp: return s.mcpAllowed
            }
        }
        guard !search.isEmpty else { return base }
        return base.filter { $0.name.localizedCaseInsensitiveContains(search) }
    }

    var body: some View {
        NavigationSplitView(columnVisibility: .constant(.all)) {
            sidebar
        } detail: {
            detail
        }
        .toolbar { toolbar }
        .sheet(isPresented: $showAdd) {
            AddSecretSheet().environmentObject(env)
        }
        .onChange(of: highlightName) { _, name in
            guard let name, let secret = env.secrets.first(where: { $0.name == name }) else { return }
            selection = secret.id
            search = ""
            filter = .all
            onHighlightHandled?()
        }
        .onAppear { applyHighlightIfNeeded() }
        .onChange(of: env.secrets.count) { _, _ in applyHighlightIfNeeded() }
        .onChange(of: env.focusVaultSearch) { _, focus in
            guard focus else { return }
            search = ""
            filter = .all
            env.focusVaultSearch = false
        }
        .onChange(of: env.copySelectedSecret) { _, copy in
            guard copy else { return }
            env.copySelectedSecret = false
            guard let id = selection,
                  let name = env.secrets.first(where: { $0.id == id })?.name else { return }
            Task { await env.copySecret(name: name) }
        }
        .onChange(of: env.openAddSecret) { _, open in
            if open { showAdd = true }
        }
    }

    private func applyHighlightIfNeeded() {
        guard let name = highlightName,
              let secret = env.secrets.first(where: { $0.name == name }) else { return }
        selection = secret.id
        search = ""
        filter = .all
        onHighlightHandled?()
    }

    private var sidebar: some View {
        VStack(spacing: 0) {
            countLine
                .padding(.horizontal, Tokens.Space.lg)
                .padding(.top, Tokens.Space.md)
                .padding(.bottom, Tokens.Space.sm)
            Picker("", selection: $filter) {
                ForEach(Filter.allCases) { Text($0.label).tag($0) }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, Tokens.Space.lg)
            .padding(.bottom, Tokens.Space.sm)
            List(filtered, selection: $selection) { secret in
                SecretRow(secret: secret).tag(secret.id)
            }
            .listStyle(.inset)
            .scrollContentBackground(.hidden)
            .searchable(text: $search, placement: .sidebar, prompt: "Search secrets")
        }
        .background(.regularMaterial)
        .navigationTitle("Vault")
        .navigationSplitViewColumnWidth(min: 320, ideal: 380, max: 460)
    }

    private var countLine: some View {
        let rotate = env.secrets.filter(\.isRotationDue).count
        let expired = env.secrets.filter(\.isExpired).count
        return HStack(spacing: Tokens.Space.xs) {
            Text("\(env.secrets.count)")
                .font(.headline.weight(.semibold))
                .foregroundStyle(Tokens.Text.primary)
            Text("secret\(env.secrets.count == 1 ? "" : "s")")
                .font(.subheadline)
                .foregroundStyle(Tokens.Text.secondary)
            if expired > 0 {
                bullet
                Text("\(expired) expired").font(.subheadline).foregroundStyle(Tokens.Status.danger)
            }
            if rotate > 0 {
                bullet
                Text("\(rotate) due to rotate").font(.subheadline).foregroundStyle(Tokens.Status.warning)
            }
            Spacer()
        }
    }

    private var bullet: some View {
        Text("·").foregroundStyle(Tokens.Text.tertiary).font(.subheadline)
    }

    @ViewBuilder
    private var detail: some View {
        if let id = selection, let secret = env.secrets.first(where: { $0.id == id }) {
            SecretDetailView(secret: secret)
                .id(secret.id)
        } else if env.secrets.isEmpty {
            VaultEmptyState(
                isFirstRun: true,
                onAdd: { showAdd = true },
                onScan: onScanProject,
                onImport: onOpenImport
            )
        } else {
            VaultSelectHint(secretCount: env.secrets.count, onAdd: { showAdd = true })
        }
    }

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        ToolbarItemGroup(placement: .primaryAction) {
            Button { env.refresh() } label: {
                Label("Refresh", systemImage: "arrow.clockwise")
            }
            .help("Reload from Keychain")
            Button { showAdd = true } label: {
                Label("Add Secret", systemImage: "plus")
            }
            .keyboardShortcut("n", modifiers: .command)
            .help("Add secret (⌘N)")
        }
    }
}

