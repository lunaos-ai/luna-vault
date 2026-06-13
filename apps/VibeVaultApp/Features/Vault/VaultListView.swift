import SwiftUI
import VaultCore

struct VaultListView: View {
    @EnvironmentObject var env: AppEnvironment
    @EnvironmentObject var nav: Navigator
    @State private var selection: Secret.ID?
    @State private var showAdd = false
    @State private var showExportAll = false
    @State private var search = ""
    @State private var filter: Filter = .all

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
        // Deep search: name, notes, and value, ranked by best field match.
        return SecretSearch.rank(base, query: search, limit: base.count).map(\.secret)
    }

    var body: some View {
        NavigationSplitView(columnVisibility: .constant(.all)) {
            sidebar
        } detail: {
            detail
                .overlay(alignment: .bottomTrailing) {
                    FloatingActionButton(systemImage: "plus", label: "Add secret (⌘N)") {
                        showAdd = true
                    }
                    .padding(Tokens.Space.xl)
                }
        }
        .toolbar { toolbar }
        .sheet(isPresented: $showAdd) {
            AddSecretSheet().environmentObject(env)
        }
        .sheet(isPresented: $showExportAll) {
            EnvExportView(names: env.secrets.map(\.name), isPresented: $showExportAll)
                .environmentObject(env)
        }
        .onAppear(perform: consumePending)
        .onChange(of: nav.pendingSecret) { _, _ in consumePending() }
    }

    /// Honor a secret reveal requested by the command palette.
    private func consumePending() {
        guard let id = nav.pendingSecret else { return }
        selection = id
        nav.pendingSecret = nil
    }

    private var sidebar: some View {
        VStack(spacing: 0) {
            countLine
                .padding(.horizontal, Tokens.Space.lg)
                .padding(.top, Tokens.Space.md)
                .padding(.bottom, Tokens.Space.sm)

            searchBar
                .padding(.horizontal, Tokens.Space.lg)
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

            VaultSuggestionsPanel(search: $search, secretNames: env.secrets.map(\.name))
        }
        .background(.ultraThinMaterial)
        .navigationTitle("Vault")
        .navigationSplitViewColumnWidth(min: 320, ideal: 380, max: 460)
    }

    private var searchBar: some View {
        HStack(spacing: Tokens.Space.sm) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Tokens.Text.tertiary)
            TextField("Search by key name...", text: $search)
                .textFieldStyle(.plain)
            if !search.isEmpty {
                Button { search = "" } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(Tokens.Text.tertiary)
                }
                .buttonStyle(.borderless)
            }
        }
        .padding(.horizontal, Tokens.Space.md)
        .padding(.vertical, Tokens.Space.sm)
        .background(
            RoundedRectangle(cornerRadius: Tokens.Radius.md, style: .continuous)
                .fill(Tokens.Surface.elevated.opacity(0.5))
        )
        .overlay(
            RoundedRectangle(cornerRadius: Tokens.Radius.md, style: .continuous)
                .stroke(Tokens.Glass.edge, lineWidth: Tokens.Stroke.hairline)
        )
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
        } else {
            VaultEmptyState { showAdd = true }
        }
    }

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        ToolbarItemGroup(placement: .primaryAction) {
            Button { nav.paletteOpen = true } label: {
                Label("Search", systemImage: "magnifyingglass")
            }
            .keyboardShortcut("k", modifiers: .command)
            .help("Search secrets (⌘K)")

            Button { env.refresh() } label: {
                Label("Refresh", systemImage: "arrow.clockwise")
            }
            .help("Reload from Keychain")

            Button { showExportAll = true } label: {
                Label("Export .env", systemImage: "square.and.arrow.down")
            }
            .disabled(env.secrets.isEmpty)
            .help("Export all secrets to a project .env file")

            Button { showAdd = true } label: {
                Label("Add Secret", systemImage: "plus")
            }
            .keyboardShortcut("n", modifiers: .command)
            .help("Add secret (⌘N)")
        }
    }
}

