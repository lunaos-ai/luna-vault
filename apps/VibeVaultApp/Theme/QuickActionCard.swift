import SwiftUI

struct QuickActionCard: View {
    let icon: String
    let title: String
    let subtitle: String
    let tint: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: Tokens.Space.md) {
                ZStack {
                    RoundedRectangle(cornerRadius: Tokens.Radius.sm, style: .continuous)
                        .fill(tint.opacity(0.12))
                        .frame(width: 40, height: 40)
                    Image(systemName: icon)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(tint)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Tokens.Text.primary)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(Tokens.Text.secondary)
                        .lineLimit(2)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Tokens.Text.tertiary)
            }
            .padding(Tokens.Space.lg)
            .luxuryCard()
        }
        .buttonStyle(.plain)
        .pressableScale()
    }
}
