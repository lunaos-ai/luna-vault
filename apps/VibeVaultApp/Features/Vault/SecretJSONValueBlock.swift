import SwiftUI
import VaultCore

struct SecretJSONValueBlock: View {
    let revealed: Bool
    let masked: String
    let revealedValue: String

    var body: some View {
        Group {
            if revealed {
                ScrollView {
                    Text(revealedValue)
                        .font(.system(.body, design: .monospaced).weight(.medium))
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(maxHeight: 220)
            } else {
                Text(masked)
                    .font(.system(.title3, design: .monospaced).weight(.medium))
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .accessibilityLabel(revealed ? "JSON value" : "Hidden JSON value")
    }
}
