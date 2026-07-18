import SwiftUI

struct ToastBanner: View {
    let message: String

    var body: some View {
        HStack(spacing: Tokens.Space.sm) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(Tokens.Status.success)
                .symbolEffect(.bounce, value: message)
            Text(message)
                .font(.subheadline.weight(.medium))
        }
        .padding(.horizontal, Tokens.Space.lg)
        .padding(.vertical, Tokens.Space.md)
        .background(.regularMaterial, in: Capsule())
        .overlay(Capsule().strokeBorder(Tokens.Surface.separator.opacity(0.5), lineWidth: Tokens.Stroke.hairline))
        .shadow(color: .black.opacity(0.08), radius: 12, y: 4)
    }
}

struct ToastModifier: ViewModifier {
    @Binding var message: String?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content.overlay(alignment: .top) {
            if let msg = message {
                ToastBanner(message: msg)
                    .padding(.top, Tokens.Space.lg)
                    .transition(
                        reduceMotion
                            ? .opacity
                            : .move(edge: .top).combined(with: .opacity).combined(with: .scale(scale: 0.96))
                    )
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2.2) {
                            Motion.animate(reduceMotion) { message = nil }
                        }
                    }
            }
        }
        .animation(Motion.value(reduceMotion, Motion.reveal), value: message)
    }
}

extension View {
    func toast(_ message: Binding<String?>) -> some View {
        modifier(ToastModifier(message: message))
    }
}
