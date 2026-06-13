import SwiftUI

/// Circular floating action button — pinned bottom-trailing over content.
struct FloatingActionButton: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let systemImage: String
    let label: String
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 52, height: 52)
                .background(
                    LinearGradient(
                        colors: [Tokens.Palette.accent, Tokens.Palette.accent.opacity(0.8)],
                        startPoint: .top, endPoint: .bottom
                    ),
                    in: Circle()
                )
                .overlay(
                    Circle().fill(
                        LinearGradient(colors: [Color.white.opacity(0.35), .clear],
                                       startPoint: .top, endPoint: .center)
                    ).blendMode(.plusLighter)
                )
                .overlay(Circle().strokeBorder(Color.white.opacity(0.25), lineWidth: 0.5))
                .shadow(color: Tokens.Palette.accent.opacity(0.45), radius: hovering ? 22 : 14, y: 8)
                .scaleEffect(hovering && !reduceMotion ? 1.06 : 1)
        }
        .buttonStyle(.plain)
        .help(label)
        .accessibilityLabel(label)
        .animation(reduceMotion ? nil : Tokens.Motion.spring, value: hovering)
        .onHover { hovering = $0 }
    }
}

/// Floating glass capsule that hosts a row of controls, detached from the window edge.
struct FloatingBar<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        HStack(spacing: Tokens.Space.sm) { content }
            .padding(.horizontal, Tokens.Space.md)
            .padding(.vertical, Tokens.Space.sm)
            .glassPanel(radius: Tokens.Radius.pill, elevation: .lifted)
    }
}

/// Pill chip on glass — replaces the old flat tintedChip with a translucent edge.
extension View {
    func glassChip(_ color: Color) -> some View {
        self
            .font(.caption2.weight(.semibold))
            .padding(.horizontal, Tokens.Space.sm)
            .padding(.vertical, 3)
            .background(color.opacity(0.16), in: Capsule())
            .overlay(Capsule().strokeBorder(color.opacity(0.35), lineWidth: 0.5))
            .foregroundStyle(color)
    }
}
