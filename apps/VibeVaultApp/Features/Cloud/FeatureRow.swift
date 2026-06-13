import SwiftUI

struct FeatureRow: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: Tokens.Space.sm) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundStyle(Tokens.Palette.accent)
                .frame(width: 24)
            Text(text)
                .font(.caption)
                .foregroundStyle(Tokens.Text.secondary)
        }
    }
}
