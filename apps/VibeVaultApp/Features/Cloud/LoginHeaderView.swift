import SwiftUI

struct LoginHeaderView: View {
    let isRegistering: Bool

    var body: some View {
        VStack(spacing: Tokens.Space.md) {
            Image(systemName: "icloud.and.arrow.up")
                .font(.system(size: 48))
                .foregroundStyle(Tokens.Palette.accent)

            Text(isRegistering ? "Create Account" : "Sign In")
                .font(.title2.weight(.semibold))

            Text("Enable cloud backups and sync across devices")
                .font(.subheadline)
                .foregroundStyle(Tokens.Text.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.top, Tokens.Space.xxl)
    }
}
