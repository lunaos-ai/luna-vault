import SwiftUI
import VaultCore

extension ImportView {
    var importHero: some View {
        HStack(spacing: Tokens.Space.md) {
            ZStack {
                RoundedRectangle(cornerRadius: Tokens.Radius.md, style: .continuous)
                    .fill(Tokens.Palette.accent.opacity(0.1))
                    .frame(width: 48, height: 48)
                Image(systemName: "square.and.arrow.down")
                    .font(.title3)
                    .foregroundStyle(Tokens.Palette.accent)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text("Bring secrets into the vault")
                    .font(.headline)
                Text("Clipboard, screenshots, dotenv, shell env, or 1Password CLI.")
                    .font(.caption)
                    .foregroundStyle(Tokens.Text.secondary)
            }
            Spacer()
        }
        .padding(.horizontal, Tokens.Space.xxl)
        .padding(.top, Tokens.Space.md)
        .padding(.bottom, Tokens.Space.sm)
    }

}

struct CompactImportSection<Content: View>: View {
    let title: String
    let footer: String?
    private let content: Content

    init(
        title: String,
        footer: String? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.footer = footer
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.xs) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Tokens.Text.primary)

            VStack(alignment: .leading, spacing: Tokens.Space.sm) {
                content
            }
            .padding(Tokens.Space.sm)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                Tokens.Surface.elevated.opacity(0.45),
                in: RoundedRectangle(cornerRadius: Tokens.Radius.sm, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Tokens.Radius.sm, style: .continuous)
                    .strokeBorder(Tokens.Surface.separator.opacity(0.6), lineWidth: Tokens.Stroke.hairline)
            )

            if let footer {
                Text(footer)
                    .font(.caption)
                    .foregroundStyle(Tokens.Text.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, Tokens.Space.xs)
            }
        }
    }
}

struct PasswordAppImportButton: View {
    let profile: PasswordManagerImportProfile
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: Tokens.Space.xs) {
                Image(systemName: profile.systemImage)
                    .font(.body)
                    .foregroundStyle(profile.tint)
                Text(profile.label)
                    .font(.subheadline.weight(.semibold))
                Text(profile.subtitle)
                    .font(.caption)
                    .foregroundStyle(Tokens.Text.secondary)
            }
            .frame(maxWidth: .infinity, minHeight: 72, alignment: .topLeading)
            .padding(Tokens.Space.sm)
            .background(
                Tokens.Surface.elevated.opacity(0.7),
                in: RoundedRectangle(cornerRadius: Tokens.Radius.sm, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Tokens.Radius.sm, style: .continuous)
                    .strokeBorder(Tokens.Surface.separator.opacity(0.5), lineWidth: Tokens.Stroke.hairline)
            )
        }
        .buttonStyle(.plain)
    }
}

private extension PasswordManagerImportProfile {
    var subtitle: String {
        switch self {
        case .auto: return "CSV from any app"
        case .applePasswords: return "Passwords export"
        case .bitwarden: return "Vault CSV"
        case .onePasswordCSV: return "CSV export"
        case .lastPass: return "CSV export"
        case .dashlane: return "CSV export"
        }
    }

    var systemImage: String {
        switch self {
        case .auto: return "wand.and.stars"
        case .applePasswords: return "apple.logo"
        case .bitwarden: return "shield"
        case .onePasswordCSV: return "1.circle"
        case .lastPass: return "ellipsis.rectangle"
        case .dashlane: return "bolt.shield"
        }
    }

    var tint: Color {
        switch self {
        case .auto: return Tokens.Palette.accent
        case .applePasswords: return Tokens.Text.primary
        case .bitwarden: return Tokens.Status.info
        case .onePasswordCSV: return Tokens.Palette.mint
        case .lastPass: return Tokens.Palette.rose
        case .dashlane: return Tokens.Palette.warm
        }
    }
}
