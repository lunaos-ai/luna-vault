import SwiftUI
import VaultCore

struct AddSecretSheet: View {
    @EnvironmentObject var env: AppEnvironment
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var value = ""
    @State private var notes = ""
    @State private var hasExpiry = false
    @State private var expiresAt = Date().addingTimeInterval(60 * 60 * 24 * 90)
    @State private var rotateEnabled = false
    @State private var rotateDays = 90
    @State private var mcpAllowed = false
    @State private var hasMFA = false
    @State private var totpSetup = ""

    var body: some View {
        Form {
            Section {
                TextField("NAME", text: $name, prompt: Text("CF_API_TOKEN"))
                    .font(.system(.body, design: .monospaced))
                SecureField("Value", text: $value)
                TextField("Notes", text: $notes, prompt: Text("Optional"))
            } header: {
                Text("Secret")
            }

            SecretValueGeneratorSection(value: $value)

            Section {
                Toggle("Set expiry", isOn: $hasExpiry)
                if hasExpiry {
                    DatePicker("Expires on", selection: $expiresAt, displayedComponents: .date)
                }
            } header: {
                Text("Expiry")
            } footer: {
                Text("Vibe Vault warns you when secrets are about to expire.")
            }

            Section {
                Toggle("Rotate periodically", isOn: $rotateEnabled)
                if rotateEnabled {
                    Stepper("Every \(rotateDays) days", value: $rotateDays, in: 7...365, step: 7)
                }
            } header: {
                Text("Rotation")
            } footer: {
                Text("Tracks when each secret was last rotated. CLI: `vibevault rotate <NAME>`.")
            }

            Section {
                Toggle("Attach MFA code", isOn: $hasMFA)
                if hasMFA {
                    TextField("Setup key or otpauth:// URL", text: $totpSetup)
                        .font(.system(.body, design: .monospaced))
                    if !totpSetup.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, normalizedTOTP == nil {
                        Text("Enter a valid authenticator setup key or otpauth URL.")
                            .font(.caption)
                            .foregroundStyle(Tokens.Status.warning)
                    }
                }
            } header: {
                Text("MFA code")
            } footer: {
                Text("Attach the rotating 6-digit code used by services that require two-factor authentication.")
            }

            Section {
                Toggle("Allow AI agents", isOn: $mcpAllowed)
            } header: {
                Text("Access")
            } footer: {
                Text("When on, AI agents using the Vibe Vault MCP server (Claude Code, Cursor, etc.) can read this secret. Every read is audited.")
            }
        }
        .formStyle(.grouped)
        .frame(minWidth: 480, minHeight: 480)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    env.addSecret(
                        name: name,
                        value: value,
                        notes: notes.isEmpty ? nil : notes,
                        expiresAt: hasExpiry ? expiresAt : nil,
                        rotateEveryDays: rotateEnabled ? rotateDays : nil,
                        mcpAllowed: mcpAllowed,
                        totpAuthURL: hasMFA ? normalizedTOTP : nil
                    )
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(name.isEmpty || value.isEmpty || !mfaInputValid)
            }
        }
    }

    private var normalizedTOTP: String? {
        try? TOTPGenerator.normalizedAuthURL(from: totpSetup, label: name.isEmpty ? "VibeVault" : name)
    }

    private var mfaInputValid: Bool {
        guard hasMFA else { return true }
        return normalizedTOTP != nil
    }
}
