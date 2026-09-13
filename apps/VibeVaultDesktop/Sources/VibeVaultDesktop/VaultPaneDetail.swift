import SwiftCrossUI
import VaultCore

struct VaultPaneDetail: View {
    @Binding var model: DesktopModel
    var onRefresh: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if model.showAddForm {
                addForm
            } else if let name = model.selectedName {
                secretDetail(name)
            } else {
                Text("Select a secret, or add one.")
                    .foregroundColor(.gray)
            }
            Spacer()
        }
        .padding(8)
        .frame(minWidth: 360)
    }

    @ViewBuilder
    private func secretDetail(_ name: String) -> some View {
        Text(name).font(.system(size: 18, weight: .semibold))
        Text(model.revealedValue ?? "••••••••")
            .font(.system(size: 14, design: .monospaced))
        if let notes = model.selectedNotes, !notes.isEmpty {
            Text(notes).foregroundColor(.gray)
        }
        HStack {
            Button("Reveal") { reveal(name) }
            Button("Hide") { model.revealedValue = nil }
            Button("Copy name") { copy(name, label: "name") }
            Button("Copy value") { copyValue(name) }
        }
        HStack {
            Text(model.selectedMCPAllowed ? "AI agents allowed" : "AI agents blocked")
            Button(model.selectedMCPAllowed ? "Revoke AI" : "Allow AI") {
                toggleMCP(name)
            }
        }
        Text("Reads require unlock on Linux/Windows (Unlock tab).")
            .foregroundColor(.gray)
            .font(.system(size: 12))
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
                    model.draftName = ""
                    model.draftValue = ""
                    model.draftNotes = ""
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
                model.selectedNotes = secret.notes
                model.selectedMCPAllowed = secret.mcpAllowed
                model.statusMessage = "Revealed \(name)"
                model.errorMessage = nil
            } catch {
                model.errorMessage = error.localizedDescription
            }
        }
    }

    private func copy(_ text: String, label: String) {
        if PlatformClipboard.copy(text) {
            model.statusMessage = "Copied \(label)"
            model.errorMessage = nil
        } else {
            model.errorMessage = "Could not copy \(label)"
        }
    }

    private func copyValue(_ name: String) {
        Task {
            do {
                let secret = try await DesktopVault.service()
                    .read(name: name, reason: "Desktop copy \(name)")
                copy(secret.value, label: name)
            } catch {
                model.errorMessage = error.localizedDescription
            }
        }
    }

    private func toggleMCP(_ name: String) {
        Task {
            do {
                let next = !model.selectedMCPAllowed
                try await DesktopVault.service().setMCPAllowed(name: name, allowed: next)
                model.selectedMCPAllowed = next
                model.statusMessage = next ? "Allowed AI access" : "Revoked AI access"
                onRefresh()
            } catch {
                model.errorMessage = error.localizedDescription
            }
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
            model.draftName = ""
            model.draftValue = ""
            model.draftNotes = ""
            model.selectedName = name
            model.statusMessage = "Saved \(name)"
            onRefresh()
        } catch {
            model.errorMessage = error.localizedDescription
        }
    }
}
