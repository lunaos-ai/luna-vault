import SwiftCrossUI
import VaultCore

struct VaultPane: View {
    @Binding var model: DesktopModel
    var onRefresh: () -> Void

    var body: some View {
        NavigationSplitView {
            VStack(alignment: .leading, spacing: 8) {
                Text("Secrets (\(model.secretNames.count))")
                    .font(.system(size: 13, weight: .medium))
                TextField("Search", text: $model.search)
                ScrollView {
                    List(
                        model.visibleSecretNames,
                        id: \.self,
                        selection: $model.selectedName
                    ) { name in
                        Text(name)
                    }
                    .padding(4)
                }
                .frame(minWidth: 220)
                HStack {
                    Button("Add") { model.showAddForm.toggle() }
                    Button("Duplicate") { duplicateSelected() }
                    Button("Delete") { deleteSelected() }
                }
            }
        } detail: {
            VaultPaneDetail(model: $model, onRefresh: onRefresh)
        }
    }

    private func duplicateSelected() {
        guard let name = model.selectedName else { return }
        Task {
            do {
                let copyName = try await DesktopVault.service().duplicate(name: name)
                model.selectedName = copyName
                model.revealedValue = nil
                model.statusMessage = "Duplicated as \(copyName)"
                model.errorMessage = nil
                onRefresh()
            } catch {
                model.errorMessage = error.localizedDescription
            }
        }
    }

    private func deleteSelected() {
        guard let name = model.selectedName else { return }
        do {
            try DesktopVault.service().delete(name: name)
            model.selectedName = nil
            model.revealedValue = nil
            model.statusMessage = "Deleted \(name)"
            onRefresh()
        } catch {
            model.errorMessage = error.localizedDescription
        }
    }
}
