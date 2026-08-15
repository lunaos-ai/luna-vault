import SwiftUI
import VaultCore

extension VaultListView {
    @ToolbarContentBuilder
    var toolbar: some ToolbarContent {
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
            Menu {
                Button { showAdd = true } label: {
                    Label("Secret", systemImage: "key")
                }
                Button { showAddVerificationCode = true } label: {
                    Label("Verification Code", systemImage: "number.square")
                }
            } label: {
                Label("Add", systemImage: "plus")
            }
            .help("Add a secret or verification code")
            .disabled(isSelecting)

            Button {
                showRecentlyDeleted = true
            } label: {
                Label("Recently Deleted", systemImage: recentlyDeletedCount > 0 ? "trash.fill" : "trash")
            }
            .help(recentlyDeletedCount > 0 ? "Recently deleted (\(recentlyDeletedCount))" : "Recently deleted")
            .disabled(isSelecting)
        }
    }

    func enterSelectMode() {
        multiSelection = selection.map { [$0] } ?? []
        selection = nil
        isSelecting = true
    }

    func exitSelectMode() {
        if multiSelection.count == 1 { selection = multiSelection.first }
        multiSelection = []
        isSelecting = false
    }

    func applyBulkMCP(allowed: Bool) async {
        let names = Set(multiSelection)
        guard !names.isEmpty else { return }
        await env.setMCPAllowed(for: names, allowed: allowed)
    }

    func applyHighlight(_ name: String?) {
        guard let name, let secret = env.secrets.first(where: { $0.name == name }) else { return }
        if isSelecting { exitSelectMode() }
        selection = secret.id
        search = ""
        filter = .all
        onHighlightHandled?()
    }

    func refreshRecentlyDeletedCount() {
        recentlyDeletedCount = (try? env.service.deletedSecretRevisionSummaries().count) ?? 0
    }
}
