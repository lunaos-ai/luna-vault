import SwiftUI
import VaultCore

struct SecretDetailView: View {
    @EnvironmentObject var env: AppEnvironment
    let secret: Secret
    @State private var revealed = false
    @State private var revealedValue = ""
    @State private var deleteConfirm = false
    @State private var showRotateSheet = false
    @State private var rotateNewValue = ""

    var body: some View {
        Form {
            Section {
                LabeledContent {
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
                    if !badges.isEmpty {
                        HStack(spacing: 6) { ForEach(badges, id: \.text) { badge($0) } }
                    }
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
                Button { Task { await rotate() } } label: {
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
        .sheet(isPresented: $showRotateSheet) { rotateSheet }
    }

    private var rotateSheet: some View {
        Form {
            Section {
                SecureField("New value", text: $rotateNewValue)
            } header: {
                Text("Rotate \(secret.name)")
            } footer: {
                Text("Audit log records who rotated and when. Cloud provider copies are not updated.")
            }
        }
        .formStyle(.grouped)
        .frame(minWidth: 440, minHeight: 220)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { showRotateSheet = false }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Rotate") {
                    Task {
                        await env.rotate(name: secret.name, newValue: rotateNewValue)
                        showRotateSheet = false
                    }
                }
                .keyboardShortcut(.defaultAction)
                .disabled(rotateNewValue.isEmpty)
            }
        }
    }

    private struct Badge {
        let text: String
        let icon: String
        let tint: Color
    }

    private var badges: [Badge] {
        var out: [Badge] = []
        if secret.isExpired {
            out.append(Badge(text: "Expired", icon: "exclamationmark.triangle.fill", tint: .red))
        } else if let exp = secret.expiresAt {
            let days = Calendar.current.dateComponents([.day], from: Date(), to: exp).day ?? 0
            if days < 14 {
                out.append(Badge(text: "Expires in \(days)d", icon: "clock", tint: .orange))
            }
        }
        if secret.isRotationDue {
            out.append(Badge(text: "Rotate due", icon: "arrow.triangle.2.circlepath", tint: .red))
        }
        return out
    }

    private func badge(_ b: Badge) -> some View {
        HStack(spacing: 4) {
            Image(systemName: b.icon)
            Text(b.text)
        }
        .font(.caption2)
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(b.tint.opacity(0.15), in: Capsule())
        .foregroundStyle(b.tint)
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

    private func rotate() async {
        rotateNewValue = ""
        showRotateSheet = true
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
