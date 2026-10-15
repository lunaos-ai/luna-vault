import SwiftUI
import VaultCore

struct AddSecretValueFields: View {
    @Binding var name: String
    @Binding var value: String
    @Binding var notes: String
    @Binding var valueKind: SecretValueKind
    var clipboardNote: String? = nil

    var body: some View {
        Section {
            TextField("NAME", text: $name, prompt: Text("CF_API_TOKEN"))
                .font(.system(.body, design: .monospaced))
            Picker("Format", selection: $valueKind) {
                ForEach(SecretValueKind.allCases, id: \.self) { kind in
                    Text(kind.label).tag(kind)
                }
            }
            .pickerStyle(.segmented)
            .onChange(of: valueKind) { _, newKind in
                if newKind == .json, let pretty = try? SecretJSON.prettyPrinted(value) {
                    value = pretty
                }
            }
            if valueKind == .json {
                SecretJSONEditor(text: $value, errorMessage: jsonError, minHeight: 220)
                    .listRowInsets(EdgeInsets(top: 8, leading: 12, bottom: 8, trailing: 12))
            } else {
                RevealableSecureField(title: "Value", text: $value)
            }
            if valueKind == .text, SecretJSON.looksLikeObjectOrArray(value) {
                Button("Switch to JSON") {
                    valueKind = .json
                    if let pretty = try? SecretJSON.prettyPrinted(value) {
                        value = pretty
                    }
                }
                .font(.caption)
            }
            TextField("Notes", text: $notes, prompt: Text("Optional"))
        } header: {
            Text("Secret")
        } footer: {
            Text(footerText)
        }

        if valueKind == .text {
            SecretValueGeneratorSection(value: $value)
        }
    }

    private var footerText: String {
        let format = valueKind == .json
            ? "Stored as pretty-printed JSON. Use this for service accounts and other structured credentials."
            : "Plain text token, password, or URL."
        if let clipboardNote { return "\(clipboardNote) \(format)" }
        return format
    }

    private var jsonError: String? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard valueKind == .json, !trimmed.isEmpty else { return nil }
        if (try? SecretJSON.prettyPrinted(value)) != nil { return nil }
        return "Enter a JSON object or array."
    }
}
