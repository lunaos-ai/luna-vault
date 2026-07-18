import SwiftUI
import VaultCore

enum VaultListFilter: String, CaseIterable, Identifiable {
    case all, expiring, rotateDue = "rotate", mcp
    var id: String { rawValue }
    var label: String {
        switch self {
        case .all: return "All"
        case .expiring: return "Expiring"
        case .rotateDue: return "Rotate due"
        case .mcp: return "AI-allowed"
        }
    }
}

func vaultFilteredSecrets(
    _ secrets: [Secret],
    filter: VaultListFilter,
    search: String
) -> [Secret] {
    let base = secrets.filter { s in
        switch filter {
        case .all: return true
        case .expiring:
            return s.isExpired || (s.expiresAt.map {
                Calendar.current.dateComponents([.day], from: Date(), to: $0).day ?? 99
            } ?? 99) < 14
        case .rotateDue: return s.isRotationDue
        case .mcp: return s.mcpAllowed
        }
    }
    guard !search.isEmpty else { return base }
    return base.filter { $0.name.localizedCaseInsensitiveContains(search) }
}

struct VaultSecretsCountLine: View {
    let secrets: [Secret]

    var body: some View {
        let rotate = secrets.filter(\.isRotationDue).count
        let expired = secrets.filter(\.isExpired).count
        HStack(spacing: Tokens.Space.xs) {
            Text("\(secrets.count)")
                .font(.headline.weight(.semibold))
                .foregroundStyle(Tokens.Text.primary)
            Text("secret\(secrets.count == 1 ? "" : "s")")
                .font(.subheadline)
                .foregroundStyle(Tokens.Text.secondary)
            if expired > 0 {
                Text("·").foregroundStyle(Tokens.Text.tertiary).font(.subheadline)
                Text("\(expired) expired").font(.subheadline).foregroundStyle(Tokens.Status.danger)
            }
            if rotate > 0 {
                Text("·").foregroundStyle(Tokens.Text.tertiary).font(.subheadline)
                Text("\(rotate) due to rotate").font(.subheadline).foregroundStyle(Tokens.Status.warning)
            }
            Spacer()
        }
    }
}
