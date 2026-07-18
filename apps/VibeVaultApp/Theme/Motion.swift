import SwiftUI

/// Calm locksmith-bench motion. Always honors Reduce Motion.
enum Motion {
    static let snappy = Animation.spring(response: 0.32, dampingFraction: 0.86)
    static let soft = Animation.easeInOut(duration: 0.22)
    static let reveal = Animation.spring(response: 0.42, dampingFraction: 0.88)

    static func animate(_ reduceMotion: Bool, _ body: () -> Void) {
        if reduceMotion {
            body()
        } else {
            withAnimation(snappy, body)
        }
    }

    static func value(_ reduceMotion: Bool, _ preferred: Animation) -> Animation? {
        reduceMotion ? nil : preferred
    }
}

struct AppearFade: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var shown = false

    func body(content: Content) -> some View {
        content
            .opacity(shown || reduceMotion ? 1 : 0)
            .offset(y: shown || reduceMotion ? 0 : 6)
            .onAppear {
                Motion.animate(reduceMotion) { shown = true }
            }
    }
}

struct PressableScale: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var pressed = false

    func body(content: Content) -> some View {
        content
            .scaleEffect(pressed && !reduceMotion ? 0.98 : 1)
            .animation(Motion.value(reduceMotion, Motion.soft), value: pressed)
            .simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in pressed = true }
                    .onEnded { _ in pressed = false }
            )
    }
}

extension View {
    func appearFade() -> some View { modifier(AppearFade()) }
    func pressableScale() -> some View { modifier(PressableScale()) }
    func bounceIfMotion<V: Equatable>(_ value: V) -> some View {
        modifier(BounceIfMotion(value: value))
    }
}

struct BounceIfMotion<V: Equatable>: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let value: V

    func body(content: Content) -> some View {
        // Prefer a single view type; system already softens effects under Reduce Motion.
        content.symbolEffect(.bounce, options: reduceMotion ? .nonRepeating : .default, value: value)
    }
}
