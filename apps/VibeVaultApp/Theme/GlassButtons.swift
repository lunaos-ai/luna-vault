import SwiftUI

/// Translucent glass button — for secondary actions on glass scenes.
struct GlassButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var tint: Color = Tokens.Text.primary

    func makeBody(configuration: Configuration) -> some View {
        let shape = RoundedRectangle(cornerRadius: Tokens.Radius.sm, style: .continuous)
        return configuration.label
            .font(.system(.body, design: .rounded).weight(.medium))
            .foregroundStyle(tint)
            .padding(.horizontal, Tokens.Space.md)
            .padding(.vertical, Tokens.Space.sm)
            .background(.ultraThinMaterial, in: shape)
            .overlay(shape.strokeBorder(Tokens.Glass.edge, lineWidth: Tokens.Stroke.hairline))
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.96 : 1)
            .animation(reduceMotion ? nil : Tokens.Motion.snappy, value: configuration.isPressed)
    }
}

/// Prominent accent button with a glass sheen — the single primary action per region.
struct GlassProminentButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var tint: Color = Tokens.Palette.accent

    func makeBody(configuration: Configuration) -> some View {
        let shape = RoundedRectangle(cornerRadius: Tokens.Radius.sm, style: .continuous)
        return configuration.label
            .font(.system(.body, design: .rounded).weight(.semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, Tokens.Space.lg)
            .padding(.vertical, Tokens.Space.sm)
            .background(
                LinearGradient(
                    colors: [tint, tint.opacity(0.82)],
                    startPoint: .top, endPoint: .bottom
                ),
                in: shape
            )
            .overlay(
                shape.fill(
                    LinearGradient(colors: [Color.white.opacity(0.3), .clear],
                                   startPoint: .top, endPoint: .center)
                ).blendMode(.plusLighter).allowsHitTesting(false)
            )
            .overlay(shape.strokeBorder(Color.white.opacity(0.25), lineWidth: Tokens.Stroke.hairline))
            .shadow(color: tint.opacity(0.35), radius: configuration.isPressed ? 6 : 12, y: 5)
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.96 : 1)
            .animation(reduceMotion ? nil : Tokens.Motion.snappy, value: configuration.isPressed)
    }
}

extension ButtonStyle where Self == GlassButtonStyle {
    static var glass: GlassButtonStyle { GlassButtonStyle() }
    static func glass(tint: Color) -> GlassButtonStyle { GlassButtonStyle(tint: tint) }
}

extension ButtonStyle where Self == GlassProminentButtonStyle {
    static var glassProminent: GlassProminentButtonStyle { GlassProminentButtonStyle() }
}
