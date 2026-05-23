import SwiftUI
import VaultCore

struct VaultListView: View {
    @EnvironmentObject var env: AppEnvironment
    @State private var selection: Secret.ID?
    @State private var showAdd = false
    @State private var search = ""

    private var filtered: [Secret] {
        guard !search.isEmpty else { return env.secrets }
        return env.secrets.filter { $0.name.localizedCaseInsensitiveContains(search) }
    }

    var body: some View {
        NavigationSplitView(columnVisibility: .constant(.all)) {
            List(filtered, selection: $selection) { secret in
                SecretRow(secret: secret).tag(secret.id)
            }
            .listStyle(.inset)
            .searchable(text: $search, placement: .sidebar, prompt: "Search secrets")
            .navigationTitle("Vault")
            .navigationSplitViewColumnWidth(min: 280, ideal: 340)
        } detail: {
            if let id = selection, let secret = env.secrets.first(where: { $0.id == id }) {
                SecretDetailView(secret: secret)
            } else {
                ContentUnavailableView(
                    "No secret selected",
                    systemImage: "key.viewfinder",
                    description: Text("Pick one from the list or add a new secret.")
                )
            }
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showAdd = true
                } label: {
                    Label("Add Secret", systemImage: "plus")
                }
            }
        }
        .sheet(isPresented: $showAdd) {
            AddSecretSheet().environmentObject(env)
        }
    }
}

struct SecretRow: View {
    let secret: Secret
    var body: some View {
        HStack(spacing: 10) {
            ZStack {
                Circle().fill(.tint.opacity(0.15)).frame(width: 28, height: 28)
                Image(systemName: "key.fill").font(.caption).foregroundStyle(.tint)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(secret.name).font(.system(.body, design: .monospaced))
                HStack(spacing: 4) {
                    Text(secret.updatedAt, style: .relative)
                    if secret.isExpired {
                        Text("· expired").foregroundStyle(.red)
                    } else if let exp = secret.expiresAt {
                        Text("· expires \(exp.formatted(.relative(presentation: .named)))")
                    }
                    if secret.isRotationDue {
                        Text("· rotate due").foregroundStyle(.red)
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            Spacer()
            if secret.isExpired || secret.isRotationDue {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.red)
                    .font(.caption)
            }
        }
        .padding(.vertical, 2)
    }
}

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
        Form {
            Section {
                TextField("NAME", text: $name, prompt: Text("CF_API_TOKEN"))
                    .font(.system(.body, design: .monospaced))
                SecureField("Value", text: $value)
                TextField("Notes", text: $notes, prompt: Text("Optional"))
            } header: {
                Text("Secret")
            }

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
                Toggle("Allow AI agents", isOn: $mcpAllowed)
            } header: {
                Text("Access")
            } footer: {
                Text("When on, AI agents using the Vibe Vault MCP server (Claude Code, Cursor, etc.) can read this secret. Every read is audited.")
            }
        }
        .formStyle(.grouped)
        .frame(minWidth: 480, minHeight: 460)
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
                        mcpAllowed: mcpAllowed
                    )
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(name.isEmpty || value.isEmpty)
            }
        }
    }
}
