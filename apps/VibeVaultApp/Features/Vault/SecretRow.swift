import SwiftUI
import VaultCore

struct SecretRow: View {
    let secret: Secret
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isHovering = false

    var body: some View {
        HStack(spacing: Tokens.Space.md) {
            avatar
            VStack(alignment: .leading, spacing: 3) {
                Text(secret.name)
                    .font(.system(.body, design: .monospaced).weight(.medium))
                    .tracking(-0.2)
                    .lineLimit(1)
                rowSubtitle
            }
            Spacer()
            trailing
        }
        .padding(.horizontal, Tokens.Space.xs)
        .padding(.vertical, 6)
        .background(
            isHovering ? Tokens.Palette.accent.opacity(0.06) : Color.clear,
            in: RoundedRectangle(cornerRadius: Tokens.Radius.sm, style: .continuous)
        )
        .scaleEffect(isHovering && !reduceMotion ? 1.01 : 1)
        .animation(Motion.value(reduceMotion, Motion.soft), value: isHovering)
        .contentShape(Rectangle())
        .onHover { hovering in
            Motion.animate(reduceMotion) { isHovering = hovering }
        }
        // Do not attach pressableScale here — DragGesture steals List selection on macOS.
    }

    private var avatar: some View {
        Image(systemName: "key.fill")
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(Tokens.Text.tertiary)
            .frame(width: 22, height: 22)
            .background(
                Tokens.Surface.elevated.opacity(0.5),
                in: RoundedRectangle(cornerRadius: 5, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .strokeBorder(Tokens.Surface.separator.opacity(0.4), lineWidth: Tokens.Stroke.hairline)
            )
    }

    @ViewBuilder
    private var trailing: some View {
        if secret.isExpired || secret.isRotationDue {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(Tokens.Status.danger)
                .font(.caption)
                .accessibilityLabel("Needs attention")
        } else if secret.mcpAllowed {
            Image(systemName: "sparkles")
                .foregroundStyle(Tokens.Palette.accent)
                .font(.caption2)
                .accessibilityLabel("AI-allowed")
        }
    }

    private var rowSubtitle: some View {
        HStack(spacing: 4) {
            Text(secret.updatedAt, style: .relative)
            if secret.isExpired {
                Text("· expired").foregroundStyle(Tokens.Status.danger)
            } else if let exp = secret.expiresAt {
                Text("· expires \(exp.formatted(.relative(presentation: .named)))")
            }
            if secret.isRotationDue {
                Text("· rotate due").foregroundStyle(Tokens.Status.danger)
            }
        }
        .font(.caption)
        .foregroundStyle(Tokens.Text.secondary)
    }
}
