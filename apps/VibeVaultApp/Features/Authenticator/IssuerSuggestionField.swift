import SwiftUI

struct IssuerIcon: View {
    let name: String
    var size: CGFloat = 28

    var body: some View {
        Group {
            if let symbol = AuthenticatorIssuerCatalog.resolve(name)?.systemImage {
                Image(systemName: symbol)
            } else {
                Text(monogram)
                    .font(.system(size: size * 0.38, weight: .semibold, design: .rounded))
            }
        }
        .foregroundStyle(Tokens.Text.secondary)
        .frame(width: size, height: size)
        .background(Tokens.Surface.elevated, in: RoundedRectangle(cornerRadius: size * 0.25))
        .overlay {
            RoundedRectangle(cornerRadius: size * 0.25)
                .stroke(Tokens.Surface.separator.opacity(0.6), lineWidth: 0.5)
        }
        .accessibilityHidden(true)
    }

    private var monogram: String {
        String(name.trimmingCharacters(in: .whitespacesAndNewlines).prefix(1)).uppercased()
    }
}

struct IssuerSuggestionField: View {
    @Binding var text: String
    let existingIssuers: [String]
    @FocusState private var focused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.xs) {
            HStack(spacing: Tokens.Space.sm) {
                IssuerIcon(name: text)
                TextField("Issuer", text: $text)
                    .textFieldStyle(.roundedBorder)
                    .focused($focused)
                    .accessibilityLabel("Issuer")
            }
            if focused, !suggestions.isEmpty {
                VStack(spacing: 0) {
                    ForEach(suggestions) { issuer in
                        Button { select(issuer) } label: {
                            HStack(spacing: Tokens.Space.sm) {
                                IssuerIcon(name: issuer.name, size: 24)
                                Text(issuer.name)
                                Spacer()
                            }
                            .padding(.horizontal, Tokens.Space.sm)
                            .padding(.vertical, 6)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Use issuer \(issuer.name)")
                        if issuer.id != suggestions.last?.id { Divider() }
                    }
                }
                .background(Tokens.Surface.elevated, in: RoundedRectangle(cornerRadius: Tokens.Radius.sm))
                .overlay {
                    RoundedRectangle(cornerRadius: Tokens.Radius.sm)
                        .stroke(Tokens.Surface.separator.opacity(0.6), lineWidth: 0.5)
                }
            }
        }
    }

    private var suggestions: [AuthenticatorIssuer] {
        AuthenticatorIssuerCatalog.suggestions(for: text, existingIssuers: existingIssuers)
    }

    private func select(_ issuer: AuthenticatorIssuer) {
        text = issuer.name
        focused = false
    }
}
