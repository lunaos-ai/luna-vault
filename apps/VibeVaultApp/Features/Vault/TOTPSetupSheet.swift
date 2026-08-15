import SwiftUI
import VaultCore

struct TOTPSetupSheet: View {
    @EnvironmentObject var env: AppEnvironment
    @Environment(\.dismiss) private var dismiss
    let secretName: String
    @Binding var unlockedAuthURL: String?
    @State private var setupValue: String

    init(secretName: String, unlockedAuthURL: Binding<String?>) {
        self.secretName = secretName
        _unlockedAuthURL = unlockedAuthURL
        _setupValue = State(initialValue: unlockedAuthURL.wrappedValue ?? "")
    }

    var body: some View {
        Form {
            Section {
                TextField("Setup key or otpauth:// URL", text: $setupValue)
                    .font(.system(.body, design: .monospaced))
                if !setupValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, normalized == nil {
                    Text("Enter a valid authenticator setup key or otpauth URL.")
                        .font(.caption)
                        .foregroundStyle(Tokens.Status.warning)
                }
            } header: {
                Text("MFA code")
            } footer: {
                Text("The setup key is stored with this credential and only revealed after authentication.")
            }
        }
        .formStyle(.grouped)
        .frame(minWidth: 460, minHeight: 240)
        .navigationTitle("MFA code")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
            ToolbarItem(placement: .destructiveAction) {
                Button("Remove") {
                    Task {
                        await env.setTOTP(name: secretName, authURL: nil)
                        unlockedAuthURL = nil
                        dismiss()
                    }
                }
                .disabled(unlockedAuthURL == nil)
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    guard let normalized else { return }
                    Task {
                        await env.setTOTP(name: secretName, authURL: normalized)
                        unlockedAuthURL = normalized
                        dismiss()
                    }
                }
                .keyboardShortcut(.defaultAction)
                .disabled(normalized == nil)
            }
        }
    }

    private var normalized: String? {
        try? TOTPGenerator.normalizedAuthURL(from: setupValue, label: secretName)
    }
}
