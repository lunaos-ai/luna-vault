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
                ScrollView {
                    List(
                        model.secretNames,
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
                    Button("Delete") { deleteSelected() }
                }
            }
        } detail: {
            detailBody
        }
    }

    @ViewBuilder
    private var detailBody: some View {
        VStack(alignment: .leading, spacing: 10) {
            if model.showAddForm {
                addForm
            } else if let name = model.selectedName {
                Text(name).font(.system(size: 18, weight: .semibold))
                Text(model.revealedValue ?? "••••••••")
                    .font(.system(size: 14, design: .monospaced))
                HStack {
                    Button("Reveal") { reveal(name) }
                    Button("Hide") { model.revealedValue = nil }
                }
                Text("Reads require unlock on Linux/Windows (Unlock tab).")
                    .foregroundColor(.gray)
                    .font(.system(size: 12))
            } else {
                Text("Select a secret, or add one.")
                    .foregroundColor(.gray)
            }
            Spacer()
        }
        .padding(8)
        .frame(minWidth: 360)
    }

    private var addForm: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("New secret").font(.system(size: 16, weight: .semibold))
            TextField("NAME", text: $model.draftName)
            TextField("Value", text: $model.draftValue)
            TextField("Notes (optional)", text: $model.draftNotes)
            HStack {
                Button("Save") { saveDraft() }
                Button("Cancel") {
                    model.showAddForm = false
                    clearDraft()
                }
            }
        }
    }

    private func reveal(_ name: String) {
        Task {
            do {
                let secret = try await DesktopVault.service()
                    .read(name: name, reason: "Desktop reveal \(name)")
                model.revealedValue = secret.value
                model.statusMessage = "Revealed \(name)"
                model.errorMessage = nil
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

    private func saveDraft() {
        let name = model.draftName.trimmingCharacters(in: .whitespacesAndNewlines)
        let value = model.draftValue
        guard !name.isEmpty, !value.isEmpty else {
            model.errorMessage = "Name and value are required."
            return
        }
        do {
            let notes = model.draftNotes.isEmpty ? nil : model.draftNotes
            try DesktopVault.service().add(name: name, value: value, notes: notes)
            model.showAddForm = false
            clearDraft()
            model.selectedName = name
            model.statusMessage = "Saved \(name)"
            onRefresh()
        } catch {
            model.errorMessage = error.localizedDescription
        }
    }

    private func clearDraft() {
        model.draftName = ""
        model.draftValue = ""
        model.draftNotes = ""
    }
}
