import SwiftUI
import VaultCore

struct SecretDetailView: View {
    @EnvironmentObject var env: AppEnvironment
    let secret: Secret
    @State private var revealed = false
    @State private var revealedValue = ""
    @State private var deleteConfirm = false
    @State private var showRotateSheet = false

    var body: some View {
        Form {
            Section {
                LabeledContent {
                    valueRow
                } label: {
                    Text("Value")
                }
                LabeledContent("Updated", value: secret.updatedAt.formatted(date: .abbreviated, time: .standard))
                if let last = secret.lastRotatedAt {
                    LabeledContent("Last rotated", value: last.formatted(date: .abbreviated, time: .omitted))
                }
                if let notes = secret.notes, !notes.isEmpty {
                    LabeledContent("Notes", value: notes)
                }
            } header: {
                HStack {
                    Text(secret.name)
                        .font(.system(.title3, design: .monospaced))
                        .textCase(nil)
                        .foregroundStyle(.primary)
                    Spacer()
                    SecretBadgeStrip(secret: secret)
                }
            }

            if secret.expiresAt != nil || secret.rotateEveryDays != nil {
                Section {
                    if let exp = secret.expiresAt {
                        LabeledContent("Expires", value: exp.formatted(date: .abbreviated, time: .omitted))
                    }
                    if let every = secret.rotateEveryDays {
                        LabeledContent("Rotate every", value: "\(every) days")
                    }
                    if let due = secret.rotationDueAt {
                        LabeledContent("Rotation due", value: due.formatted(date: .abbreviated, time: .omitted))
                    }
                } header: {
                    Text("Schedule")
                }
            }

            Section {
                Toggle("Allow AI agents (MCP)", isOn: Binding(
                    get: { secret.mcpAllowed },
                    set: { newVal in Task { await env.setMCPAllowed(name: secret.name, allowed: newVal) } }
                ))
            } header: {
                Text("Access")
            } footer: {
                Text("When on, AI agents connected via the Vibe Vault MCP server (Claude Code, Cursor, etc.) can read this secret. Every read is audited.")
            }

            Section {
                Button { showRotateSheet = true } label: {
                    Label("Rotate value…", systemImage: "arrow.triangle.2.circlepath")
                }
                Button { Task { await markRotated() } } label: {
                    Label("Mark rotated now", systemImage: "checkmark.circle")
                }
                .help("Records rotation without changing the value (e.g. you rotated at the provider).")
                Button(role: .destructive) { deleteConfirm = true } label: {
                    Label("Delete secret", systemImage: "trash")
                }
            } header: {
                Text("Actions")
            }
        }
        .formStyle(.grouped)
        .navigationTitle(secret.name)
        .navigationSubtitle(secret.updatedAt.formatted(.relative(presentation: .named)))
        .confirmationDialog(
            "Delete \(secret.name)?",
            isPresented: $deleteConfirm,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) { env.deleteSecret(name: secret.name) }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This removes the secret from your local Keychain. Cloud provider copies are not revoked.")
        }
        .sheet(isPresented: $showRotateSheet) {
            RotateSheetView(secret: secret, isPresented: $showRotateSheet)
                .environmentObject(env)
        }
    }

    private var valueRow: some View {
        HStack(spacing: 8) {
            Text(revealed ? revealedValue : secret.maskedValue)
                .font(.system(.body, design: .monospaced))
                .textSelection(.enabled)
                .lineLimit(1)
                .truncationMode(.tail)
            Button {
                Task { await reveal() }
            } label: {
                Image(systemName: revealed ? "eye.slash" : "eye")
            }
            .buttonStyle(.borderless)
            Button {
                copy()
            } label: {
                Image(systemName: "doc.on.doc")
            }
            .buttonStyle(.borderless)
            .help("Copy value (requires Touch ID)")
        }
    }

    private func reveal() async {
        if revealed { revealed = false; revealedValue = ""; return }
        do {
            let fresh = try await env.service.read(name: secret.name, reason: "Reveal \(secret.name)")
            revealedValue = fresh.value
            revealed = true
        } catch {
            env.lastError = "\(error)"
        }
    }

    private func copy() {
        Task {
            do {
                let fresh = try await env.service.read(name: secret.name, reason: "Copy \(secret.name)")
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(fresh.value, forType: .string)
            } catch {
                env.lastError = "\(error)"
            }
        }
    }

    private func markRotated() async {
        do {
            try await env.service.rotate(name: secret.name, newValue: nil)
            env.refresh()
        } catch {
            env.lastError = "\(error)"
        }
    }
}
