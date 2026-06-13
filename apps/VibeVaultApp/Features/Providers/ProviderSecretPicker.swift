import SwiftUI
import VaultCore

/// Searchable, toggle-able list of vault secrets to push to a provider.
/// Hosted inside a glass card by `ProviderSyncView`.
struct ProviderSecretPicker: View {
    let secrets: [Secret]
    @Binding var secretSearch: String
    @Binding var selectedSecrets: Set<String>

    private var filteredSecrets: [Secret] {
        guard !secretSearch.isEmpty else { return secrets }
        return secrets.filter { $0.name.localizedCaseInsensitiveContains(secretSearch) }
    }

    var body: some View {
        if secrets.isEmpty {
            Text("Vault is empty. Add or import secrets first.")
                .foregroundStyle(Tokens.Text.secondary)
        } else {
            searchField
            secretList
        }
    }

    private var searchField: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .font(.caption)
                .foregroundStyle(Tokens.Text.secondary)
            TextField("Search keys", text: $secretSearch)
                .textFieldStyle(.plain)
            if !secretSearch.isEmpty {
                Button { secretSearch = "" } label: {
                    Image(systemName: "xmark.circle.fill")
                }
                .buttonStyle(.borderless)
                .foregroundStyle(.tertiary)
                .accessibilityLabel("Clear search")
            }
        }
        .padding(.vertical, 2)
    }

    private var secretList: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                ForEach(filteredSecrets) { secret in
                    Toggle(isOn: binding(for: secret.name)) {
                        Text(secret.name).font(.system(.body, design: .monospaced))
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .frame(maxHeight: 240)
    }

    private func binding(for name: String) -> Binding<Bool> {
        Binding(
            get: { selectedSecrets.contains(name) },
            set: { on in
                if on { selectedSecrets.insert(name) }
                else { selectedSecrets.remove(name) }
            }
        )
    }
}
