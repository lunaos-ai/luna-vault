import SwiftUI
import VaultCore

/// Edit a secret value and optionally switch between text and JSON.
struct EditSecretValueSheet: View {
    @EnvironmentObject var env: AppEnvironment
    let secret: Secret
    @Binding var isPresented: Bool

    @State private var draft = ""
    @State private var kind: SecretValueKind
    @State private var loaded = false
    @State private var saving = false

    init(secret: Secret, isPresented: Binding<Bool>) {
        self.secret = secret
        _isPresented = isPresented
        _kind = State(initialValue: secret.valueKind)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.lg) {
            Text("Edit \(secret.name)")
                .font(.title2.weight(.semibold))
                .fontDesign(.monospaced)
            Picker("Format", selection: $kind) {
                ForEach(SecretValueKind.allCases, id: \.self) { option in
                    Text(option.label).tag(option)
                }
            }
            .pickerStyle(.segmented)
            .onChange(of: kind) { _, newKind in
                if newKind == .json, let pretty = try? SecretJSON.prettyPrinted(draft) {
                    draft = pretty
                }
            }

            if kind == .json {
                SecretJSONEditor(text: $draft, errorMessage: jsonError, minHeight: 200)
            } else {
                RevealableSecureField(title: "Value", text: $draft)
            }

            HStack {
                Button("Cancel", role: .cancel) { isPresented = false }
                    .disabled(saving)
                Spacer()
                Button("Save") { Task { await save() } }
                    .buttonStyle(.borderedProminent)
                    .tint(Tokens.Palette.accent)
                    .disabled(!canSave || saving)
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(Tokens.Space.xl)
        .frame(width: 560)
        .frame(minHeight: kind == .json ? 480 : 280)
        .task { await load() }
        .interactiveDismissDisabled(saving)
    }

    private var jsonError: String? {
        let trimmed = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard kind == .json, !trimmed.isEmpty else { return nil }
        if (try? SecretJSON.prettyPrinted(draft)) != nil { return nil }
        return "Enter a JSON object or array."
    }

    private var canSave: Bool {
        loaded && !draft.isEmpty && jsonError == nil
    }

    private func load() async {
        do {
            let fresh = try await env.service.read(name: secret.name, reason: "Edit \(secret.name)")
            draft = fresh.value
            kind = fresh.valueKind
            loaded = true
        } catch {
            env.lastError = "\(error)"
            isPresented = false
        }
    }

    private func save() async {
        saving = true
        defer { saving = false }
        do {
            try await env.service.updateValue(name: secret.name, value: draft, valueKind: kind)
            env.refresh()
            env.showToast("Updated \(secret.name)")
            isPresented = false
        } catch {
            env.lastError = "\(error)"
            env.showToast("Could not update secret", feedback: .caution)
        }
    }
}
