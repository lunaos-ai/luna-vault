import SwiftUI
import VaultCore

struct RecoveryCodesSheet: View {
    @EnvironmentObject var env: AppEnvironment
    @Environment(\.dismiss) var dismiss
    let accountID: UUID
    @State private var values = ""
    @State private var saving = false

    var body: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.lg) {
            Text("Import recovery codes").font(.title2.weight(.semibold))
            Text("Paste comma-separated or one code per line. Existing recovery codes will be replaced.")
                .foregroundStyle(Tokens.Text.secondary)
                .fixedSize(horizontal: false, vertical: true)
            TextEditor(text: $values)
                .font(.system(.body, design: .monospaced))
                .frame(minHeight: 180)
                .overlay(RoundedRectangle(cornerRadius: Tokens.Radius.sm)
                    .stroke(Tokens.Surface.separator, lineWidth: Tokens.Stroke.hairline))
            HStack {
                Button("Cancel", role: .cancel) { clearAndDismiss() }
                Spacer()
                Button("Save") { Task { await save() } }
                    .buttonStyle(.borderedProminent)
                    .disabled(parsedValues.isEmpty || saving)
            }
        }
        .padding(Tokens.Space.xl)
        .frame(width: 500)
        .interactiveDismissDisabled(saving)
        .onDisappear { values = "" }
    }

    private var parsedValues: [String] {
        values.components(separatedBy: CharacterSet(charactersIn: ",\n"))
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    private func save() async {
        saving = true
        defer { saving = false }
        do {
            try await env.authenticatorService.addRecoveryCodes(id: accountID, values: parsedValues)
            env.refreshAuthenticators()
            env.showToast("Recovery codes saved", feedback: .success)
            clearAndDismiss()
        } catch {
            env.lastError = "\(error)"
            env.showToast("Could not save recovery codes", feedback: .caution)
        }
    }

    private func clearAndDismiss() {
        values = ""
        dismiss()
    }
}
