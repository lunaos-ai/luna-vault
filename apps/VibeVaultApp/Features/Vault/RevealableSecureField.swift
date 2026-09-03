import SwiftUI

/// Secret-value field: masked by default, with a trailing eye toggle.
struct RevealableSecureField: View {
    let title: String
    @Binding var text: String

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @FocusState private var focused: Bool
    @State private var revealed = false

    var body: some View {
        LabeledContent(title) {
            HStack(spacing: Tokens.Space.sm) {
                Group {
                    if revealed {
                        TextField("", text: $text)
                            .font(.system(.body, design: .monospaced))
                            .textSelection(.enabled)
                            .autocorrectionDisabled()
                    } else {
                        SecureField("", text: $text)
                    }
                }
                .focused($focused)
                .labelsHidden()
                .accessibilityLabel(title)

                revealButton
            }
        }
    }

    private var revealButton: some View {
        Button {
            Motion.animate(reduceMotion) { revealed.toggle() }
            focused = true
        } label: {
            Image(systemName: revealed ? "eye.slash" : "eye")
                .font(.system(size: 14, weight: .medium))
                .contentTransition(.symbolEffect(.replace))
        }
        .buttonStyle(.borderless)
        .foregroundStyle(Tokens.Text.secondary)
        .pressableScale()
        .help(revealed ? "Hide value" : "Show value")
        .accessibilityLabel(revealed ? "Hide value" : "Show value")
        .accessibilityHint("Shows or hides the secret value.")
    }
}
