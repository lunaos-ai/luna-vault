import SwiftUI

/// Styled status row for project-scan import results — calm, content-first,
/// color-tinted by outcome instead of a bare wall of gray text.
struct ScanStatusBanner: View {
    let text: String

    private var isError: Bool { text.hasPrefix("error:") }
    private var isWin: Bool { text.hasPrefix("Imported") }

    private var tint: Color {
        isError ? Tokens.Status.danger : (isWin ? Tokens.Status.success : Tokens.Text.secondary)
    }

    private var glyph: String {
        isError ? "exclamationmark.octagon.fill"
            : (isWin ? "checkmark.circle.fill" : "info.circle.fill")
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: Tokens.Space.sm) {
            Image(systemName: glyph)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(tint)
            Text(text)
                .font(.callout)
                .foregroundStyle(Tokens.Text.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, Tokens.Space.md)
        .padding(.vertical, Tokens.Space.sm)
        .glassPanel(radius: Tokens.Radius.md, elevation: .resting, tint: tint.opacity(0.10))
        .overlay(
            RoundedRectangle(cornerRadius: Tokens.Radius.md, style: .continuous)
                .strokeBorder(tint.opacity(0.30), lineWidth: Tokens.Stroke.hairline)
        )
    }
}
