import SwiftUI
import VaultCore

/// Autocomplete panel for the vault search field. Owns the suggestion
/// derivation and inline highlighting so VaultListView stays a thin shell.
struct VaultSuggestionsPanel: View {
    @Binding var search: String
    let secretNames: [String]

    /// Autocomplete: key names matching the query, prefix matches first, capped.
    private var suggestions: [String] {
        guard !search.isEmpty else { return [] }
        let query = search.trimmingCharacters(in: .whitespaces)
        let names = secretNames
            .filter { $0.localizedCaseInsensitiveContains(query) }
        guard !(names.count == 1 && names[0].caseInsensitiveCompare(query) == .orderedSame)
        else { return [] }
        let prefixed = names.filter { $0.lowercased().hasPrefix(query.lowercased()) }.sorted()
        let rest = names.filter { !$0.lowercased().hasPrefix(query.lowercased()) }.sorted()
        return Array((prefixed + rest).prefix(10))
    }

    var body: some View {
        if !search.isEmpty && !suggestions.isEmpty {
            VStack(alignment: .leading, spacing: 0) {
                Text("Suggestions")
                    .font(.caption)
                    .foregroundStyle(Tokens.Text.tertiary)
                    .padding(.horizontal, Tokens.Space.lg)
                    .padding(.vertical, Tokens.Space.xs)
                ForEach(suggestions, id: \.self) { name in
                    Button {
                        search = name
                    } label: {
                        HStack {
                            Image(systemName: "key.fill")
                                .font(.system(size: 11))
                                .foregroundStyle(Tokens.Palette.accent)
                            highlightedSuggestion(name: name, query: search)
                                .font(.system(.body, design: .monospaced))
                                .lineLimit(1)
                            Spacer()
                        }
                        .padding(.horizontal, Tokens.Space.lg)
                        .padding(.vertical, Tokens.Space.xs)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical, Tokens.Space.xs)
            .background(Tokens.Surface.elevated.opacity(0.3))
        }
    }

    /// Highlights the matching portion of the suggestion in bold
    @ViewBuilder
    private func highlightedSuggestion(name: String, query: String) -> some View {
        let q = query.trimmingCharacters(in: .whitespaces).lowercased()
        let lowerName = name.lowercased()
        if let range = lowerName.range(of: q), !q.isEmpty {
            let prefix = String(name[..<range.lowerBound])
            let match = String(name[range.lowerBound..<range.upperBound])
            let suffix = String(name[range.upperBound...])
            Text(prefix) +
            Text(match).bold().foregroundStyle(Tokens.Palette.accent) +
            Text(suffix)
        } else {
            Text(name)
        }
    }
}
