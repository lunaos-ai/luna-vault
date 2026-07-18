import SwiftUI
import VaultCore

struct VaultListView: View {
    @EnvironmentObject var env: AppEnvironment
    @State private var selection: Secret.ID?
    @State private var multiSelection: Set<Secret.ID> = []
    @State private var isSelecting = false
    @State private var showAdd = false
    @State private var search = ""
    @State private var filter: VaultListFilter = .all
    var highlightName: String? = nil
    var onHighlightHandled: (() -> Void)? = nil
    var onScanProject: (() -> Void)? = nil
    var onOpenImport: (() -> Void)? = nil

    private var filtered: [Secret] {
        vaultFilteredSecrets(env.secrets, filter: filter, search: search)
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
        .onChange(of: highlightName) { _, name in applyHighlight(name) }
        .onAppear { applyHighlight(highlightName) }
        .onChange(of: env.secrets.count) { _, _ in applyHighlight(highlightName) }
        .onChange(of: env.focusVaultSearch) { _, focus in
            guard focus else { return }
            search = ""; filter = .all; env.focusVaultSearch = false
        }
        .onChange(of: env.copySelectedSecret) { _, copy in
            guard copy else { return }
            env.copySelectedSecret = false
            guard !isSelecting,
                  let id = selection,
                  let name = env.secrets.first(where: { $0.id == id })?.name else { return }
            Task { await env.copySecret(name: name) }
        }
        .onChange(of: env.openAddSecret) { _, open in
            if open { showAdd = true }
        }
    }

    private var sidebar: some View {
        VStack(spacing: 0) {
            KeychainMigrationBanner()
                .environmentObject(env)
                .padding(.horizontal, Tokens.Space.lg)
                .padding(.top, Tokens.Space.sm)
            VaultSecretsCountLine(secrets: env.secrets)
                .padding(.horizontal, Tokens.Space.lg)
                .padding(.top, Tokens.Space.md)
                .padding(.bottom, Tokens.Space.sm)
            Picker("", selection: $filter) {
                ForEach(VaultListFilter.allCases) { Text($0.label).tag($0) }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, Tokens.Space.lg)
            .padding(.bottom, Tokens.Space.sm)
            secretList
            if isSelecting {
                VaultSelectBar(
                    selectedCount: multiSelection.count,
                    onAllow: { Task { await applyBulkMCP(allowed: true) } },
                    onRevoke: { Task { await applyBulkMCP(allowed: false) } },
                    onCancel: exitSelectMode
                )
            }
        }
        .background(.regularMaterial)
        .navigationTitle("Vault")
        .navigationSplitViewColumnWidth(min: 320, ideal: 380, max: 460)
    }

    @ViewBuilder
    private var secretList: some View {
        Group {
            if isSelecting {
                List(filtered, selection: $multiSelection) { row in
                    SecretRow(secret: row).tag(row.id)
                }
            } else {
                List(filtered, selection: $selection) { row in
                    SecretRow(secret: row).tag(row.id)
                }
            }
        }
        .listStyle(.inset)
        .scrollContentBackground(.hidden)
        .searchable(text: $search, placement: .sidebar, prompt: "Search secrets")
    }

    @ViewBuilder
    private var detail: some View {
        if isSelecting {
            VaultBulkSelectDetail(
                selectedCount: multiSelection.count,
                onAllow: { Task { await applyBulkMCP(allowed: true) } },
                onRevoke: { Task { await applyBulkMCP(allowed: false) } }
            )
        } else if let id = selection, let secret = env.secrets.first(where: { $0.id == id }) {
            SecretDetailView(secret: secret).id(secret.id)
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
            .help("Reload secrets")
            if isSelecting {
                Button("Done", action: exitSelectMode)
                    .keyboardShortcut(.defaultAction)
                    .help("Leave select mode")
            } else {
                Button { enterSelectMode() } label: {
                    Label("Select", systemImage: "checkmark.circle")
                }
                .help("Select multiple secrets")
                .disabled(env.secrets.isEmpty)
            }
            Button { showAdd = true } label: {
                Label("Add Secret", systemImage: "plus")
            }
            .keyboardShortcut("n", modifiers: .command)
            .help("Add secret (⌘N)")
            .disabled(isSelecting)
        }
    }

    private func enterSelectMode() {
        multiSelection = selection.map { [$0] } ?? []
        selection = nil
        isSelecting = true
    }

    private func exitSelectMode() {
        if multiSelection.count == 1 { selection = multiSelection.first }
        multiSelection = []
        isSelecting = false
    }

    private func applyBulkMCP(allowed: Bool) async {
        let names = Set(multiSelection)
        guard !names.isEmpty else { return }
        await env.setMCPAllowed(for: names, allowed: allowed)
    }

    private func applyHighlight(_ name: String?) {
        guard let name, let secret = env.secrets.first(where: { $0.name == name }) else { return }
        if isSelecting { exitSelectMode() }
        selection = secret.id
        search = ""
        filter = .all
        onHighlightHandled?()
    }
}
