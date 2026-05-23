import SwiftUI
import VaultCore

struct VaultListView: View {
    @EnvironmentObject var env: AppEnvironment
    @State private var selection: Secret.ID?
    @State private var showAdd = false

    var body: some View {
        HSplitView {
            VStack(spacing: 0) {
                HStack {
                    Text("Secrets").font(.title2.bold())
                    Spacer()
                    Button { showAdd = true } label: {
                        Label("Add", systemImage: "plus")
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Tokens.Color.primary)
                }
                .padding(Tokens.Space.lg)

                List(env.secrets, selection: $selection) { secret in
                    SecretRow(secret: secret).tag(secret.id)
                }
                .listStyle(.inset)
            }
            .frame(minWidth: 320)

            if let id = selection, let secret = env.secrets.first(where: { $0.id == id }) {
                SecretDetailView(secret: secret)
            } else {
                Text("Select a secret")
                    .foregroundStyle(Tokens.Color.textSecondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
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
        HStack {
            Image(systemName: "key.fill")
                .foregroundStyle(Tokens.Color.primary)
            VStack(alignment: .leading) {
                Text(secret.name).font(.system(.body, design: .monospaced))
                Text(secret.updatedAt, style: .relative)
                    .font(.caption)
                    .foregroundStyle(Tokens.Color.textSecondary)
            }
        }
        .padding(.vertical, Tokens.Space.xs)
    }
}

struct AddSecretSheet: View {
    @EnvironmentObject var env: AppEnvironment
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var value = ""
    @State private var notes = ""

    var body: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.lg) {
            Text("Add secret").font(.title2.bold())
            TextField("NAME (e.g. CF_API_TOKEN)", text: $name)
                .textFieldStyle(.roundedBorder)
                .font(.system(.body, design: .monospaced))
            SecureField("Value", text: $value)
                .textFieldStyle(.roundedBorder)
            TextField("Notes (optional)", text: $notes)
                .textFieldStyle(.roundedBorder)
            HStack {
                Button("Cancel") { dismiss() }
                Spacer()
                Button("Save") {
                    env.addSecret(name: name, value: value, notes: notes.isEmpty ? nil : notes)
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .tint(Tokens.Color.primary)
                .disabled(name.isEmpty || value.isEmpty)
            }
        }
        .padding(Tokens.Space.xl)
        .frame(width: 460)
    }
}
