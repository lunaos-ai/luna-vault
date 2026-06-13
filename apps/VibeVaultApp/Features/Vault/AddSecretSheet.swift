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

    var body: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.lg) {
            Text("New Secret")
                .font(.system(.title2, design: .rounded).weight(.semibold))
                .foregroundStyle(Tokens.Text.primary)

            ScrollView {
                fields.glassCard()
            }

            actionBar
        }
        .padding(Tokens.Space.xl)
        .frame(width: 480)
        .frame(minHeight: 480)
        .background(CompactLiquidBackdrop())
    }

    private var fields: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.lg) {
            field("Secret") {
                TextField("NAME", text: $name, prompt: Text("CF_API_TOKEN"))
                    .font(.system(.body, design: .monospaced))
                    .textFieldStyle(.roundedBorder)
                SecureField("Value", text: $value)
                    .textFieldStyle(.roundedBorder)
                TextField("Notes", text: $notes, prompt: Text("Optional"))
                    .textFieldStyle(.roundedBorder)
            }

            Divider().overlay(Tokens.Surface.separator)

            field("Expiry") {
                Toggle("Set expiry", isOn: $hasExpiry)
                    .toggleStyle(.switch)
                if hasExpiry {
                    DatePicker("Expires on", selection: $expiresAt, displayedComponents: .date)
                }
                footnote("Vibe Vault warns you when secrets are about to expire.")
            }

            Divider().overlay(Tokens.Surface.separator)

            field("Rotation") {
                Toggle("Rotate periodically", isOn: $rotateEnabled)
                    .toggleStyle(.switch)
                if rotateEnabled {
                    Stepper("Every \(rotateDays) days", value: $rotateDays, in: 7...365, step: 7)
                }
                footnote("Tracks when each secret was last rotated. CLI: `vibevault rotate <NAME>`.")
            }

            Divider().overlay(Tokens.Surface.separator)

            field("Access") {
                Toggle("Allow AI agents", isOn: $mcpAllowed)
                    .toggleStyle(.switch)
                footnote("When on, AI agents using the Vibe Vault MCP server (Claude Code, Cursor, etc.) can read this secret. Every read is audited.")
            }
        }
    }

    @ViewBuilder
    private func field<Content: View>(
        _ title: String, @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: Tokens.Space.sm) {
            Text(title).sectionLabel()
            content()
        }
    }

    private func footnote(_ text: String) -> some View {
        Text(text)
            .font(.footnote)
            .foregroundStyle(Tokens.Text.secondary)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var actionBar: some View {
        HStack {
            Button("Cancel") { dismiss() }
                .buttonStyle(.glass)
            Spacer()
            Button("Save") {
                env.addSecret(
                    name: name,
                    value: value,
                    notes: notes.isEmpty ? nil : notes,
                    expiresAt: hasExpiry ? expiresAt : nil,
                    rotateEveryDays: rotateEnabled ? rotateDays : nil,
                    mcpAllowed: mcpAllowed
                )
                dismiss()
            }
            .buttonStyle(.glassProminent)
            .keyboardShortcut(.defaultAction)
            .disabled(name.isEmpty || value.isEmpty)
        }
    }
}
