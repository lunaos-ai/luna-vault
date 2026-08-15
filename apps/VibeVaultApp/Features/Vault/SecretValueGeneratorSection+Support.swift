import Foundation
import SwiftUI
import VaultCore

struct GeneratedStrength {
    let label: String
    let color: Color
    let detail: String
}


extension SecretValueGeneratorSection {
    static func generatedStrength(format: SecretValueFormat, length: Int, prefix: String) -> GeneratedStrength {
        let bits: Double
        switch format {
        case .hex:
            bits = Double(length) * 4
        case .base64URL, .base64:
            bits = Double(length) * 6
        case .password:
            bits = Double(length) * log2(75)
        case .uuid:
            bits = 122
        case .prefixedToken:
            let tokenPrefix = "\(SecretValueGenerator.normalizedPrefix(prefix))_"
            bits = Double(max(8, length - tokenPrefix.count)) * 6
        }
        if bits >= 180 {
            return GeneratedStrength(label: "Very strong", color: Tokens.Status.success, detail: "\(Int(bits)) bits estimated entropy")
        }
        if bits >= 96 {
            return GeneratedStrength(label: "Strong", color: Tokens.Palette.mint, detail: "\(Int(bits)) bits estimated entropy")
        }
        return GeneratedStrength(label: "Short", color: Tokens.Status.warning, detail: "\(Int(bits)) bits estimated entropy")
    }
}

enum GeneratorTemplate: String, CaseIterable, Identifiable {
    case providerAPIKey
    case webhookSecret
    case databasePassword
    case humanPassword
    case csrfToken
    case uuid

    var id: String { rawValue }

    var title: String {
        switch self {
        case .providerAPIKey: return "API key"
        case .webhookSecret: return "Webhook"
        case .databasePassword: return "Database"
        case .humanPassword: return "Password"
        case .csrfToken: return "CSRF"
        case .uuid: return "UUID"
        }
    }

    var subtitle: String {
        switch self {
        case .providerAPIKey: return "URL-safe token"
        case .webhookSecret: return "Prefixed token"
        case .databasePassword: return "CLI-safe password"
        case .humanPassword: return "Long app password"
        case .csrfToken: return "Hex secret"
        case .uuid: return "Identifier"
        }
    }

    var systemImage: String {
        switch self {
        case .providerAPIKey: return "key.fill"
        case .webhookSecret: return "point.3.connected.trianglepath.dotted"
        case .databasePassword: return "cylinder.split.1x2"
        case .humanPassword: return "person.badge.key"
        case .csrfToken: return "shield.lefthalf.filled"
        case .uuid: return "number"
        }
    }

    var format: SecretValueFormat {
        switch self {
        case .providerAPIKey: return .base64URL
        case .webhookSecret: return .prefixedToken
        case .databasePassword, .humanPassword: return .password
        case .csrfToken: return .hex
        case .uuid: return .uuid
        }
    }

    var length: Int {
        switch self {
        case .providerAPIKey: return 48
        case .webhookSecret: return 48
        case .databasePassword: return 40
        case .humanPassword: return 28
        case .csrfToken: return 64
        case .uuid: return 36
        }
    }

    var prefix: String {
        switch self {
        case .webhookSecret: return "whsec"
        default: return "vv"
        }
    }
}

struct GeneratorTemplateButton: View {
    let template: GeneratorTemplate
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: Tokens.Space.sm) {
                HStack {
                    Image(systemName: template.systemImage)
                        .foregroundStyle(isSelected ? Tokens.Palette.accent : Tokens.Text.secondary)
                    Spacer()
                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(Tokens.Palette.accent)
                    }
                }
                Text(template.title)
                    .font(.subheadline.weight(.semibold))
                Text(template.subtitle)
                    .font(.caption)
                    .foregroundStyle(Tokens.Text.secondary)
            }
            .frame(maxWidth: .infinity, minHeight: 82, alignment: .topLeading)
            .padding(Tokens.Space.md)
            .background(
                isSelected ? Tokens.Palette.accent.opacity(0.12) : Tokens.Surface.elevated.opacity(0.65),
                in: RoundedRectangle(cornerRadius: Tokens.Radius.sm, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Tokens.Radius.sm, style: .continuous)
                    .strokeBorder(
                        isSelected ? Tokens.Palette.accent.opacity(0.5) : Tokens.Surface.separator.opacity(0.5),
                        lineWidth: Tokens.Stroke.hairline
                    )
            )
        }
        .buttonStyle(.plain)
    }
}
