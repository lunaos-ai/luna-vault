import SwiftUI

/// Ambient backdrop for glass scenes: a tonal base with slow-drifting blurred
/// color orbs that give the translucent surfaces something alive to refract.
/// Drift pauses entirely under Reduce Motion.
struct LiquidBackdrop: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var drift = false

    var body: some View {
        ZStack {
            Tokens.Surface.background

            orb(Tokens.Palette.accent, 420)
                .offset(x: drift ? -160 : -120, y: drift ? -200 : -160)
            orb(Tokens.Palette.mint, 320)
                .offset(x: drift ? 220 : 180, y: drift ? -60 : -20)
            orb(Tokens.Palette.warm, 360)
                .offset(x: drift ? 120 : 80, y: drift ? 260 : 300)
        }
        .ignoresSafeArea()
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 14).repeatForever(autoreverses: true)) {
                drift.toggle()
            }
        }
    }

    private func orb(_ color: Color, _ size: CGFloat) -> some View {
        Circle()
            .fill(color.opacity(0.16))
            .frame(width: size, height: size)
            .blur(radius: 90)
    }
}

/// Same family, sized for the compact menu-bar popover.
struct CompactLiquidBackdrop: View {
    var body: some View {
        ZStack {
            Tokens.Surface.background
            Circle().fill(Tokens.Palette.accent.opacity(0.14))
                .frame(width: 200, height: 200).blur(radius: 60)
                .offset(x: -70, y: -90)
        }
        .ignoresSafeArea()
    }
}
