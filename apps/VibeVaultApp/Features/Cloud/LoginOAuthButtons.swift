import SwiftUI

struct LoginOAuthButtons: View {
    @ObservedObject var cloudAuth: CloudAuthService

    var body: some View {
        VStack(spacing: Tokens.Space.sm) {
            Button {
                Task {
                    await cloudAuth.signInWithGoogle()
                }
            } label: {
                HStack(spacing: Tokens.Space.sm) {
                    Image(systemName: "g.circle.fill")
                        .foregroundStyle(.red)
                    Text("Continue with Google")
                        .fontWeight(.medium)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, Tokens.Space.sm)
            }
            .buttonStyle(.glass)
            .disabled(cloudAuth.isLoading)

            Button {
                Task {
                    await cloudAuth.signInWithGitHub()
                }
            } label: {
                HStack(spacing: Tokens.Space.sm) {
                    Image(systemName: "github")
                        .foregroundStyle(Tokens.Text.primary)
                    Text("Continue with GitHub")
                        .fontWeight(.medium)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, Tokens.Space.sm)
            }
            .buttonStyle(.glass)
            .disabled(cloudAuth.isLoading)
        }
        .padding(.horizontal, Tokens.Space.xl)
    }
}
