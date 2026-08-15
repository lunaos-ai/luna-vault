import SwiftUI
import VaultCore

struct VaultListView: View {
    @EnvironmentObject var env: AppEnvironment
    @State var selection: Secret.ID?
    @State var multiSelection: Set<Secret.ID> = []
    @State var isSelecting = false
    @State var showAdd = false
    @State var showAddVerificationCode = false
    @State var search = ""
    @State var filter: VaultListFilter = .all
    @State var sort: VaultListSort = .name
    @State var grouping: VaultListGrouping = .none
    @State var showRecentlyDeleted = false
    @State var recentlyDeletedCount = 0
    @FocusState var searchFocused: Bool
    var highlightName: String? = nil
    var onHighlightHandled: (() -> Void)? = nil
    var onScanProject: (() -> Void)? = nil
    var onOpenImport: (() -> Void)? = nil

    var filtered: [Secret] {
        vaultFilteredSecrets(env.secrets, filter: filter, search: search)
    }

    var sections: [VaultSecretSection] {
        vaultSecretSections(filtered, grouping: grouping, sort: sort)
    }

    var body: some View {
        HSplitView {
            sidebar
                .frame(minWidth: 320, idealWidth: 380, maxWidth: 460)
            detail
                .frame(minWidth: 400, maxWidth: .infinity, maxHeight: .infinity)
        }
        .toolbar { toolbar }
        .sheet(isPresented: $showAdd) {
            AddSecretSheet().environmentObject(env)
        }
        .sheet(isPresented: $showAddVerificationCode) {
            AddAuthenticatorSheet().environmentObject(env)
        }
        .sheet(isPresented: $showRecentlyDeleted) {
            RecentlyDeletedSecretsSheet().environmentObject(env)
        }
        .onChange(of: highlightName) { _, name in applyHighlight(name) }
        .onAppear {
            applyHighlight(highlightName)
            refreshRecentlyDeletedCount()
        }
        .onChange(of: env.secrets.count) { _, _ in
            applyHighlight(highlightName)
            refreshRecentlyDeletedCount()
        }
        .onChange(of: env.focusVaultSearch) { _, focus in
            guard focus else { return }
            search = ""; filter = .all; searchFocused = true; env.focusVaultSearch = false
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

    var sidebar: some View {
        VStack(spacing: 0) {
            KeychainMigrationBanner()
                .environmentObject(env)
                .padding(.horizontal, Tokens.Space.lg)
                .padding(.top, Tokens.Space.sm)
            VaultSecretsCountLine(secrets: env.secrets)
                .padding(.horizontal, Tokens.Space.lg)
                .padding(.top, Tokens.Space.md)
                .padding(.bottom, Tokens.Space.sm)
            VaultSearchField(search: $search, isFocused: $searchFocused)
                .padding(.horizontal, Tokens.Space.lg)
                .padding(.bottom, Tokens.Space.sm)
            Picker("", selection: $filter) {
                ForEach(VaultListFilter.allCases) { Text($0.label).tag($0) }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, Tokens.Space.lg)
            .padding(.bottom, Tokens.Space.sm)
            VaultListOptionsBar(sort: $sort, grouping: $grouping)
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
    }

    @ViewBuilder
    var secretList: some View {
        Group {
            if isSelecting {
                List(selection: $multiSelection) {
                    listRows
                }
            } else {
                List(selection: $selection) {
                    listRows
                }
            }
        }
        .listStyle(.inset)
        .scrollContentBackground(.hidden)
    }

    @ViewBuilder
    var listRows: some View {
        if grouping == .none {
            ForEach(sections.first?.secrets ?? []) { row in
                SecretRow(secret: row).tag(row.id)
            }
        } else {
            ForEach(sections) { section in
                Section {
                    ForEach(section.secrets) { row in
                        SecretRow(secret: row).tag(row.id)
                    }
                } header: {
                    VaultListSectionHeader(title: section.title, count: section.secrets.count)
                }
            }
        }
    }

    @ViewBuilder
    var detail: some View {
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
}
