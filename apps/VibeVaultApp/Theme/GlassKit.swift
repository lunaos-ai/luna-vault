import SwiftUI

/// Liquid Glass building blocks. Apple's `glassEffect()` is macOS 26 only, so we
/// reproduce the look on macOS 14+ with `.ultraThinMaterial`, a specular edge,
/// a faint tint, and a soft floating shadow. All motion respects Reduce Motion.

/// Floating drop shadow keyed to a semantic elevation.
private struct FloatingShadow: ViewModifier {
    let level: Tokens.Elevation
    func body(content: Content) -> some View {
        content.shadow(
            color: Color.black.opacity(level.opacity),
            radius: level.radius,
            x: 0,
            y: level.y
        )
    }
}

/// The core glass surface: material + tint + specular edge stroke + shadow.
private struct GlassSurface: ViewModifier {
    var radius: CGFloat
    var elevation: Tokens.Elevation
    var tint: Color

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        return content
            .background(.ultraThinMaterial, in: shape)
            .background(tint, in: shape)
            .overlay(
                shape.strokeBorder(
                    LinearGradient(
                        colors: [Tokens.Glass.edge, Color.white.opacity(0.04)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: Tokens.Stroke.thin
                )
            )
            .overlay(
                // Top specular sheen — the wet-glass highlight.
                shape
                    .fill(
                        LinearGradient(
                            colors: [Tokens.Glass.highlight, .clear],
                            startPoint: .top,
                            endPoint: .center
                        )
                    )
                    .blendMode(.plusLighter)
                    .allowsHitTesting(false)
            )
            .modifier(FloatingShadow(level: elevation))
    }
}

/// Hover lift — scales and raises on pointer hover, instant when Reduce Motion is on.
private struct GlassHover: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var hovering = false

    func body(content: Content) -> some View {
        content
            .scaleEffect(hovering && !reduceMotion ? 1.012 : 1)
            .shadow(
                color: Color.black.opacity(hovering ? 0.20 : 0),
                radius: hovering ? 22 : 0,
                y: hovering ? 10 : 0
            )
            .animation(reduceMotion ? nil : Tokens.Motion.snappy, value: hovering)
            .onHover { hovering = $0 }
    }
}

extension View {
    /// A floating Liquid Glass card. Pads, fills with glass, lifts off the canvas.
    func glassCard(
        radius: CGFloat = Tokens.Radius.lg,
        padding: CGFloat = Tokens.Space.lg,
        elevation: Tokens.Elevation = .floating,
        tint: Color = Tokens.Glass.tint
    ) -> some View {
        self
            .padding(padding)
            .modifier(GlassSurface(radius: radius, elevation: elevation, tint: tint))
    }

    /// Glass chrome with no internal padding — for panels that manage their own layout.
    func glassPanel(
        radius: CGFloat = Tokens.Radius.lg,
        elevation: Tokens.Elevation = .floating,
        tint: Color = Tokens.Glass.tint
    ) -> some View {
        modifier(GlassSurface(radius: radius, elevation: elevation, tint: tint))
    }

    func floatingShadow(_ level: Tokens.Elevation = .floating) -> some View {
        modifier(FloatingShadow(level: level))
    }

    func glassHover() -> some View { modifier(GlassHover()) }
}
